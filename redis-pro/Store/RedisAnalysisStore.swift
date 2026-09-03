//
//  RedisAnalysisStore.swift
//  redis-pro
//
//  Created for Real-time Memory Analysis.
//

import Foundation
import SwiftUI
import Logging
import Observation

private let logger = Logger(label: "redis-analysis-store")

private struct KeySampleDetail: Sendable {
    let key: String
    let type: String
    let ttl: Int // -1 = perm, > 0 = expires
    let memoryBytes: Int
}

@MainActor
@Observable
final class RedisAnalysisViewModel {
    var isAnalyzing: Bool = false
    var progress: Double = 0.0 // 0.0 to 1.0
    var dbSize: Int = 0
    var estCommands: Int = 0
    var policy: String = "noeviction"
    var sampleSizeOption: SampleSizeOption = .safe
    var rankBy: RankByOption = .size {
        didSet {
            sortPrefixGroups()
        }
    }

    var ttlBuckets: [TTLBucket] = [
        TTLBucket(label: "<1m", sortOrder: 0),
        TTLBucket(label: "<1h", sortOrder: 1),
        TTLBucket(label: "<1d", sortOrder: 2),
        TTLBucket(label: "<7d", sortOrder: 3),
        TTLBucket(label: ">=7d", sortOrder: 4),
        TTLBucket(label: "No TTL", sortOrder: 5)
    ]

    var prefixGroups: [AnalysisPrefixGroup] = []
    var totalSampledCount: Int = 0
    var estimatedTotalFromSample: Int = 0
    var withoutTTLPercent: Double = 100.0
    var largestBucketDescription: String = "Largest bucket: No TTL (0 keys)"

    private let redisInstance: RedisInstanceModel
    private var analysisTask: Task<Void, Never>?

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("RedisAnalysisViewModel initialized")
    }

    // MARK: - Lifecycle

    func onAppear() {
        // Only load lightweight DB metrics, DO NOT scan keys automatically
        Task {
            await loadInitialMetrics()
        }
    }

    func onDisappear() {
        stop()
    }

    func stop() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
    }

    func analyze() {
        startRealtimeAnalysis()
    }

    func loadInitialMetrics() async {
        do {
            let client = redisInstance.getClient()
            self.dbSize = try await client.dbsize()
            let memReply = try await client.execute(command: "INFO", args: ["memory"])
            let memInfo = parseInfoString(memReply.stringValue ?? "")
            self.policy = memInfo["maxmemory_policy"] ?? "noeviction"
            let statsReply = try await client.execute(command: "INFO", args: ["stats"])
            let statsInfo = parseInfoString(statsReply.stringValue ?? "")
            self.estCommands = Int(statsInfo["instantaneous_ops_per_sec"] ?? "0") ?? 0
        } catch {
            logger.warning("Failed to load initial metrics: \(error)")
        }
    }
    // MARK: - Real-time Full Analysis

    func startRealtimeAnalysis() {
        analysisTask?.cancel()
        isAnalyzing = true
        progress = 0.0

        analysisTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let client = self.redisInstance.getClient()

                // Fetch DB size and initial parameters
                await self.loadInitialMetrics()
                let currentDBSize = self.dbSize

                if currentDBSize == 0 {
                    self.progress = 1.0
                    self.isAnalyzing = false
                    self.totalSampledCount = 0
                    self.prefixGroups = []
                    self.resetBuckets()
                    return
                }

                // Sampling parameters
                let maxTargetSamples = min(currentDBSize, self.sampleSizeOption.rawValue)
                var cursor = 0
                var sampledKeys: [String] = []

                // Step 1: Collect sample keys using SCAN (COUNT 1000 for fast retrieval in 1-2 roundtrips)
                while sampledKeys.count < maxTargetSamples && !Task.isCancelled {
                    let needed = maxTargetSamples - sampledKeys.count
                    let scanBatchSize = min(1000, needed)
                    let reply = try await client.execute(command: "SCAN", args: [String(cursor), "COUNT", String(scanBatchSize)])
                    guard let arr = reply.arrayValue, arr.count >= 2 else { break }

                    cursor = arr[0].intValue ?? 0
                    let keysInBatch = arr[1].arrayValue?.compactMap { $0.stringValue } ?? []
                    sampledKeys.append(contentsOf: keysInBatch)

                    let currentRatio = Double(sampledKeys.count) / Double(maxTargetSamples)
                    self.progress = min(0.2, currentRatio * 0.2)

                    if cursor == 0 { break }
                }

                guard !Task.isCancelled else { return }

                // Step 2: Fetch details using high-speed Lua batching (50 keys per network round-trip)
                let totalKeysToInspect = sampledKeys.count
                if totalKeysToInspect == 0 {
                    self.progress = 1.0
                    self.isAnalyzing = false
                    return
                }

                var sampledDetails: [KeySampleDetail] = []
                let chunkSize = 50 // 50 keys per Lua EVAL call
                var inspectedCount = 0

                for chunk in stride(from: 0, to: totalKeysToInspect, by: chunkSize) {
                    guard !Task.isCancelled else { break }
                    let end = min(chunk + chunkSize, totalKeysToInspect)
                    let subKeys = Array(sampledKeys[chunk..<end])

                    let details = try await self.inspectKeysChunk(client: client, keys: subKeys)
                    sampledDetails.append(contentsOf: details)
                    inspectedCount += subKeys.count

                    let inspectProgress = 0.2 + (Double(inspectedCount) / Double(totalKeysToInspect)) * 0.8
                    self.progress = min(0.99, inspectProgress)
                    self.aggregateAndPublish(
                        details: sampledDetails,
                        totalInspected: inspectedCount,
                        dbSize: currentDBSize
                    )

                    // Small 10ms pause between batches to ensure server event loop stays relaxed
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }

                // Finalize
                self.aggregateAndPublish(
                    details: sampledDetails,
                    totalInspected: sampledDetails.count,
                    dbSize: currentDBSize
                )
                self.progress = 1.0
                self.isAnalyzing = false
            } catch {
                logger.error("Analysis failed: \(error)")
                self.isAnalyzing = false
                self.progress = 1.0
            }
        }
    }

    private func inspectKeysChunk(client: RedisClient, keys: [String]) async throws -> [KeySampleDetail] {
        // High-performance Lua script: inspects 50 keys in a single network round-trip in C memory
        do {
            return try await inspectKeysWithLua(client: client, keys: keys)
        } catch {
            logger.info("Lua batch inspect failed: \(error), fallback to concurrent requests")
            return await inspectKeysFallback(client: client, keys: keys)
        }
    }

    private func inspectKeysWithLua(client: RedisClient, keys: [String]) async throws -> [KeySampleDetail] {
        let script = """
        local r = {}
        for i = 1, #ARGV do
            local k = ARGV[i]
            local t_reply = redis.pcall('TYPE', k)
            local t = (type(t_reply) == 'table' and t_reply.ok) or 'none'
            local ttl = redis.pcall('TTL', k)
            if type(ttl) ~= 'number' then ttl = -1 end
            local mem = redis.pcall('MEMORY', 'USAGE', k, 'SAMPLES', '5')
            if type(mem) ~= 'number' then mem = 64 end
            r[i] = {k, t, ttl, mem}
        end
        return r
        """

        let reply = try await client.execute(command: "EVAL", args: [script, "0"] + keys)
        guard let rows = reply.arrayValue else {
            throw BizError("Invalid reply from Lua script")
        }

        var results: [KeySampleDetail] = []
        for row in rows {
            if let cols = row.arrayValue, cols.count >= 4 {
                let key = cols[0].stringValue ?? ""
                let typeStr = cols[1].stringValue ?? "none"
                let ttl = cols[2].intValue ?? -1
                let mem = cols[3].intValue ?? 64
                results.append(KeySampleDetail(key: key, type: typeStr, ttl: ttl, memoryBytes: mem))
            }
        }
        return results
    }

    private func inspectKeysFallback(client: RedisClient, keys: [String]) async -> [KeySampleDetail] {
        return await withTaskGroup(of: KeySampleDetail.self) { group in
            var results: [KeySampleDetail] = []
            var iterator = keys.makeIterator()
            let maxConcurrency = 10

            for _ in 0..<maxConcurrency {
                if let key = iterator.next() {
                    group.addTask {
                        await self.inspectSingleKey(client: client, key: key)
                    }
                }
            }

            for await detail in group {
                results.append(detail)
                if !Task.isCancelled, let nextKey = iterator.next() {
                    group.addTask {
                        await self.inspectSingleKey(client: client, key: nextKey)
                    }
                }
            }

            return results
        }
    }

    private func inspectSingleKey(client: RedisClient, key: String) async -> KeySampleDetail {
        let typeReply = try? await client.execute(command: "TYPE", args: [key])
        let typeStr = typeReply?.stringValue ?? "none"

        let ttlReply = try? await client.execute(command: "TTL", args: [key])
        let ttlVal = ttlReply?.intValue ?? -1

        var memBytes = 64
        if let reply = try? await client.execute(command: "MEMORY", args: ["USAGE", key, "SAMPLES", "5"]),
           let bytes = reply.intValue {
            memBytes = bytes
        } else if let reply = try? await client.execute(command: "MEMORY", args: ["USAGE", key]),
                  let bytes = reply.intValue {
            memBytes = bytes
        }

        return KeySampleDetail(key: key, type: typeStr, ttl: ttlVal, memoryBytes: memBytes)
    }

    private func aggregateAndPublish(details: [KeySampleDetail], totalInspected: Int, dbSize: Int) {
        guard totalInspected > 0 else { return }
        self.totalSampledCount = totalInspected

        let scaleFactor = max(1.0, Double(dbSize) / Double(totalInspected))
        self.estimatedTotalFromSample = Int(Double(totalInspected) * scaleFactor)

        // TTL aggregation
        var bucketCounts = [0, 0, 0, 0, 0, 0] // <1m, <1h, <1d, <7d, >=7d, No TTL
        var noTTLCount = 0

        // Prefix aggregation
        struct PrefixAccumulator {
            var count: Int = 0
            var memoryBytes: Int = 0
            var ttlSum: Double = 0
            var ttlKeysCount: Int = 0
            var permKeysCount: Int = 0
            var types: Set<String> = []
        }

        var prefixMap: [String: PrefixAccumulator] = [:]

        for item in details {
            // TTL bucket
            let ttl = item.ttl
            if ttl <= -1 {
                bucketCounts[5] += 1
                noTTLCount += 1
            } else if ttl < 60 {
                bucketCounts[0] += 1
            } else if ttl < 3600 {
                bucketCounts[1] += 1
            } else if ttl < 86400 {
                bucketCounts[2] += 1
            } else if ttl < 604800 {
                bucketCounts[3] += 1
            } else {
                bucketCounts[4] += 1
            }

            // Prefix group
            let prefix = extractPrefix(from: item.key)
            var acc = prefixMap[prefix] ?? PrefixAccumulator()
            acc.count += 1
            acc.memoryBytes += item.memoryBytes
            if ttl <= -1 {
                acc.permKeysCount += 1
            } else {
                acc.ttlSum += Double(ttl)
                acc.ttlKeysCount += 1
            }
            if !item.type.isEmpty && item.type != "none" {
                acc.types.insert(item.type)
            }
            prefixMap[prefix] = acc
        }

        // Update TTL Buckets
        let labels = ["<1m", "<1h", "<1d", "<7d", ">=7d", "No TTL"]
        var updatedBuckets: [TTLBucket] = []
        for i in 0..<6 {
            let count = bucketCounts[i]
            let est = Int(Double(count) * scaleFactor)
            updatedBuckets.append(TTLBucket(label: labels[i], count: count, estimatedCount: est, sortOrder: i))
        }
        self.ttlBuckets = updatedBuckets

        // Summary text
        self.withoutTTLPercent = (Double(noTTLCount) / Double(totalInspected)) * 100.0
        if let largest = updatedBuckets.max(by: { $0.count < $1.count }), largest.count > 0 {
            self.largestBucketDescription = "Largest bucket: \(largest.label) (\(largest.count.formatted()) keys)"
        } else {
            self.largestBucketDescription = "Largest bucket: No TTL (\(noTTLCount.formatted()) keys)"
        }

        // Build Prefix Groups
        var groups: [AnalysisPrefixGroup] = []
        for (prefix, acc) in prefixMap {
            let estCount = Int(Double(acc.count) * scaleFactor)
            let estMem = Int(Double(acc.memoryBytes) * scaleFactor)
            let estPerm = Int(Double(acc.permKeysCount) * scaleFactor)
            let avgTTL: Double? = acc.ttlKeysCount > 0 ? (acc.ttlSum / Double(acc.ttlKeysCount)) : nil

            let group = AnalysisPrefixGroup(
                prefix: prefix,
                sampledKeyCount: acc.count,
                estimatedKeyCount: estCount,
                sampledMemoryBytes: acc.memoryBytes,
                estimatedMemoryBytes: estMem,
                avgTTLSeconds: avgTTL,
                permKeysCount: estPerm,
                types: Array(acc.types).sorted()
            )
            groups.append(group)
        }

        self.prefixGroups = groups
        sortPrefixGroups()
    }

    private func sortPrefixGroups() {
        switch rankBy {
        case .size:
            prefixGroups.sort { $0.estimatedMemoryBytes > $1.estimatedMemoryBytes }
        case .hottest:
            prefixGroups.sort { $0.estimatedKeyCount > $1.estimatedKeyCount }
        case .coldest:
            prefixGroups.sort {
                let ttl0 = $0.avgTTLSeconds ?? Double.infinity
                let ttl1 = $1.avgTTLSeconds ?? Double.infinity
                return ttl0 > ttl1
            }
        }
    }

    private func extractPrefix(from key: String) -> String {
        if let colonIndex = key.firstIndex(of: ":") {
            let prefixPart = String(key[..<colonIndex])
            return "\(prefixPart):*"
        } else if let slashIndex = key.firstIndex(of: "/") {
            let prefixPart = String(key[..<slashIndex])
            return "\(prefixPart)/*"
        } else if let dotIndex = key.firstIndex(of: ".") {
            let prefixPart = String(key[..<dotIndex])
            return "\(prefixPart).*"
        } else {
            return key.isEmpty ? "other:*" : "\(key)"
        }
    }

    private func resetBuckets() {
        ttlBuckets = [
            TTLBucket(label: "<1m", sortOrder: 0),
            TTLBucket(label: "<1h", sortOrder: 1),
            TTLBucket(label: "<1d", sortOrder: 2),
            TTLBucket(label: "<7d", sortOrder: 3),
            TTLBucket(label: ">=7d", sortOrder: 4),
            TTLBucket(label: "No TTL", sortOrder: 5)
        ]
        withoutTTLPercent = 100.0
        largestBucketDescription = "Largest bucket: No TTL (0 keys)"
    }

    private func parseInfoString(_ info: String) -> [String: String] {
        var dict = [String: String]()
        let lines = info.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                dict[parts[0]] = parts[1]
            }
        }
        return dict
    }
}
