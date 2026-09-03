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
    var rankBy: RankByOption = .size {
        didSet {
            sortPrefixGroups()
        }
    }

    var fragmentationHistory: [FragmentationPoint] = []
    var latestFragmentationRatio: Double = 1.0
    var latestWasteBytes: Int = 0

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
    private var monitoringTask: Task<Void, Never>?

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("RedisAnalysisViewModel initialized")
    }

    // MARK: - Lifecycle

    func onAppear() {
        startRealtimeAnalysis()
        startFragmentationMonitoring()
    }

    func onDisappear() {
        stop()
    }

    func stop() {
        analysisTask?.cancel()
        analysisTask = nil
        monitoringTask?.cancel()
        monitoringTask = nil
        isAnalyzing = false
    }

    func refresh() {
        startRealtimeAnalysis()
    }

    // MARK: - Monitoring (Fragmentation Ratio & Stats every 3s)

    private func startFragmentationMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchInstantMetrics()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func fetchInstantMetrics() async {
        do {
            let client = redisInstance.getClient()

            // 1. INFO memory
            let memReply = try await client.execute(command: "INFO", args: ["memory"])
            let memInfo = parseInfoString(memReply.stringValue ?? "")

            let ratio = Double(memInfo["mem_fragmentation_ratio"] ?? "1.0") ?? 1.0
            let usedMem = Int(memInfo["used_memory"] ?? "0") ?? 0
            let rssMem = Int(memInfo["used_memory_rss"] ?? "0") ?? 0
            let waste = max(0, rssMem - usedMem)
            let maxPolicy = memInfo["maxmemory_policy"] ?? self.policy

            // 2. INFO stats
            let statsReply = try await client.execute(command: "INFO", args: ["stats"])
            let statsInfo = parseInfoString(statsReply.stringValue ?? "")
            let opsPerSec = Int(statsInfo["instantaneous_ops_per_sec"] ?? "0") ?? 0
            let totalCommands = Int(statsInfo["total_commands_processed"] ?? "0") ?? 0
            let displayCommands = opsPerSec > 0 ? opsPerSec : totalCommands

            self.latestFragmentationRatio = ratio
            self.latestWasteBytes = waste
            self.policy = maxPolicy
            self.estCommands = displayCommands

            let newPoint = FragmentationPoint(
                timestamp: Date(),
                ratio: ratio,
                wasteBytes: waste
            )
            self.fragmentationHistory.append(newPoint)
            if self.fragmentationHistory.count > 30 {
                self.fragmentationHistory.removeFirst()
            }
        } catch {
            logger.warning("Error fetching instant metrics: \(error)")
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

                // Fetch DB size
                let currentDBSize = try await client.dbsize()
                self.dbSize = currentDBSize

                // Initial fetch of metrics
                await self.fetchInstantMetrics()

                if currentDBSize == 0 {
                    self.progress = 1.0
                    self.isAnalyzing = false
                    self.totalSampledCount = 0
                    self.prefixGroups = []
                    self.resetBuckets()
                    return
                }

                // Sampling parameters
                let maxTargetSamples = min(currentDBSize, 10_000)
                var cursor = 0
                var sampledKeys: [String] = []

                // Step 1: Collect sample keys using SCAN
                while sampledKeys.count < maxTargetSamples && !Task.isCancelled {
                    let scanBatchSize = min(1000, maxTargetSamples - sampledKeys.count)
                    let reply = try await client.execute(command: "SCAN", args: [String(cursor), "COUNT", String(scanBatchSize)])
                    guard let arr = reply.arrayValue, arr.count >= 2 else { break }

                    cursor = arr[0].intValue ?? 0
                    let keysInBatch = arr[1].arrayValue?.compactMap { $0.stringValue } ?? []
                    sampledKeys.append(contentsOf: keysInBatch)

                    let currentRatio = Double(sampledKeys.count) / Double(maxTargetSamples)
                    self.progress = min(0.4, currentRatio * 0.4)

                    if cursor == 0 { break }
                }

                guard !Task.isCancelled else { return }

                // Step 2: Fetch details (TYPE, TTL, MEMORY USAGE) for sampled keys in chunks
                let totalKeysToInspect = sampledKeys.count
                if totalKeysToInspect == 0 {
                    self.progress = 1.0
                    self.isAnalyzing = false
                    return
                }

                var sampledDetails: [KeySampleDetail] = []
                let chunkSize = 100
                var inspectedCount = 0

                for chunk in stride(from: 0, to: totalKeysToInspect, by: chunkSize) {
                    guard !Task.isCancelled else { return }
                    let end = min(chunk + chunkSize, totalKeysToInspect)
                    let subKeys = Array(sampledKeys[chunk..<end])

                    let details = try await self.inspectKeysChunk(client: client, keys: subKeys)
                    sampledDetails.append(contentsOf: details)
                    inspectedCount += subKeys.count

                    let inspectProgress = 0.4 + (Double(inspectedCount) / Double(totalKeysToInspect)) * 0.6
                    self.progress = min(0.99, inspectProgress)
                    self.aggregateAndPublish(
                        details: sampledDetails,
                        totalInspected: inspectedCount,
                        dbSize: currentDBSize
                    )
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
        return try await withThrowingTaskGroup(of: KeySampleDetail.self) { group in
            for key in keys {
                group.addTask {
                    let typeReply = try? await client.execute(command: "TYPE", args: [key])
                    let typeStr = typeReply?.stringValue ?? "none"

                    let ttlReply = try? await client.execute(command: "TTL", args: [key])
                    let ttlVal = ttlReply?.intValue ?? -1

                    let memReply = try? await client.execute(command: "MEMORY", args: ["USAGE", key])
                    let memBytes = memReply?.intValue ?? 64 // fallback estimate

                    return KeySampleDetail(key: key, type: typeStr, ttl: ttlVal, memoryBytes: memBytes)
                }
            }

            var results: [KeySampleDetail] = []
            for try await detail in group {
                results.append(detail)
            }
            return results
        }
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
