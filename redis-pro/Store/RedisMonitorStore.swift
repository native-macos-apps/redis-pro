//
//  RedisMonitorStore.swift
//  redis-pro
//
//  Created for Real-time Live Monitor and Server Metrics.
//

import Foundation
import SwiftUI
import Logging

private let logger = Logger(label: "redis-pro.RedisMonitorStore")

@Observable
@MainActor
final class RedisMonitorViewModel {
    var isMonitoring: Bool = false
    var filterKeyword: String = ""
    var entries: [MonitorCommandEntry] = []
    var latestMetrics: MonitorLiveMetrics = MonitorLiveMetrics()
    var commandHistory: [CommandHistoryPoint] = []
    var fragmentationHistory: [FragmentationPoint] = []
    var latestFragmentationRatio: Double = 1.0
    var latestWasteBytes: Int = 0

    private let redisInstance: RedisInstanceModel
    private var monitorConnection: HiredisConnection?
    private var monitorTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?

    private let maxHistoryPoints = 30
    private let maxEntries = 5000

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("RedisMonitorViewModel initialized")
    }

    var filteredEntries: [MonitorCommandEntry] {
        let kw = filterKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return entries }
        return entries.filter {
            $0.command.lowercased().contains(kw) ||
            $0.arguments.lowercased().contains(kw) ||
            $0.client.lowercased().contains(kw) ||
            $0.node.lowercased().contains(kw)
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        startMonitoring()
        startMetricsPolling()
    }

    func onDisappear() {
        stopMonitoring()
        stopMetricsPolling()
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func clear() {
        entries.removeAll()
    }

    func stop() {
        stopMonitoring()
        stopMetricsPolling()
    }

    // MARK: - Monitor Streaming

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let redisModel = redisInstance.redisModel
        let host = redisModel.host
        let port = redisModel.port
        let user = redisModel.username
        let pass = redisModel.password
        let defaultNode = "\(host):\(port)"

        let conn = HiredisConnection(
            host: host,
            port: port,
            username: user,
            password: pass,
            database: 0,
            timeoutSeconds: 1.0
        )
        self.monitorConnection = conn

        monitorTask = Task.detached { [weak self, weak conn] in
            do {
                try await conn?.runMonitor { rawLine in
                    guard let entry = RedisMonitorViewModel.parseLine(rawLine, defaultNode: defaultNode) else { return }
                    Task { @MainActor in
                        guard let self = self, self.isMonitoring else { return }
                        self.entries.insert(entry, at: 0)
                        if self.entries.count > self.maxEntries {
                            self.entries.removeLast(self.entries.count - self.maxEntries)
                        }
                    }
                }
            } catch {
                logger.info("Monitor stream ended or failed: \(error)")
                Task { @MainActor in
                    self?.isMonitoring = false
                }
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
        monitorConnection?.close()
        monitorConnection = nil
    }

    // MARK: - Metrics Polling

    private func startMetricsPolling() {
        metricsTask?.cancel()
        metricsTask = Task {
            while !Task.isCancelled {
                await fetchLiveMetrics()
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s interval
            }
        }
    }

    private func stopMetricsPolling() {
        metricsTask?.cancel()
        metricsTask = nil
    }

    private func fetchLiveMetrics() async {
        do {
            let client = redisInstance.getClient()

            // Memory info
            let memReply = try await client.execute(command: "INFO", args: ["memory"])
            var usedMemHuman = "-"
            var rssHuman = "-"
            var peakHuman = "-"
            var fragRatio = 1.0
            var waste = 0

            if let info = memReply.stringValue {
                let parsed = parseInfoSection(info)
                usedMemHuman = parsed["used_memory_human"] ?? "-"
                rssHuman = parsed["used_memory_rss_human"] ?? "-"
                peakHuman = parsed["used_memory_peak_human"] ?? "-"

                if let r = parsed["mem_fragmentation_ratio"], let d = Double(r) {
                    fragRatio = d
                }
                if let used = parsed["used_memory"], let usedVal = Int(used),
                   let rss = parsed["used_memory_rss"], let rssVal = Int(rss) {
                    waste = max(0, rssVal - usedVal)
                }
            }

            // CPU info
            let cpuReply = try? await client.execute(command: "INFO", args: ["cpu"])
            var cpuSys = 0.0
            var cpuUser = 0.0
            if let cpuInfo = cpuReply?.stringValue {
                let parsed = parseInfoSection(cpuInfo)
                if let sys = parsed["used_cpu_sys"], let d = Double(sys) { cpuSys = d }
                if let usr = parsed["used_cpu_user"], let d = Double(usr) { cpuUser = d }
            }

            // Stats info (ops/sec, hits, misses, evictions)
            let statsReply = try? await client.execute(command: "INFO", args: ["stats"])
            var opsPerSec = 0
            var hits = 0
            var misses = 0
            var evictedKeys = 0
            if let statsInfo = statsReply?.stringValue {
                let parsed = parseInfoSection(statsInfo)
                if let ops = parsed["instantaneous_ops_per_sec"], let i = Int(ops) { opsPerSec = i }
                if let h = parsed["keyspace_hits"], let i = Int(h) { hits = i }
                if let m = parsed["keyspace_misses"], let i = Int(m) { misses = i }
                if let e = parsed["evicted_keys"], let i = Int(e) { evictedKeys = i }
            }

            let totalOps = hits + misses
            let hitRatio = totalOps > 0 ? (Double(hits) / Double(totalOps)) * 100.0 : 100.0

            // Clients info (connected, blocked)
            let clientsReply = try? await client.execute(command: "INFO", args: ["clients"])
            var connectedClients = 0
            var blockedClients = 0
            if let clientsInfo = clientsReply?.stringValue {
                let parsed = parseInfoSection(clientsInfo)
                if let c = parsed["connected_clients"], let i = Int(c) { connectedClients = i }
                if let b = parsed["blocked_clients"], let i = Int(b) { blockedClients = i }
            }

            // Persistence info (rdb_last_bgsave_status)
            let persistenceReply = try? await client.execute(command: "INFO", args: ["persistence"])
            var rdbStatus = "ok"
            if let persistenceInfo = persistenceReply?.stringValue {
                let parsed = parseInfoSection(persistenceInfo)
                if let s = parsed["rdb_last_bgsave_status"] { rdbStatus = s }
            }

            let wasteHuman = ByteCountFormatter.string(fromByteCount: Int64(waste), countStyle: .binary)

            self.latestMetrics = MonitorLiveMetrics(
                usedMemoryHuman: usedMemHuman,
                usedMemoryRssHuman: rssHuman,
                peakMemoryHuman: peakHuman,
                fragmentationRatio: fragRatio,
                wasteBytesHuman: wasteHuman,
                cpuSys: cpuSys,
                cpuUser: cpuUser,
                instantOpsPerSec: opsPerSec,
                hitRatio: hitRatio,
                hits: hits,
                misses: misses,
                connectedClients: connectedClients,
                blockedClients: blockedClients,
                evictedKeys: evictedKeys,
                rdbLastBgsaveStatus: rdbStatus
            )

            self.latestFragmentationRatio = fragRatio
            self.latestWasteBytes = waste

            // Update command history
            let cmdPoint = CommandHistoryPoint(timestamp: Date(), ops: opsPerSec)
            self.commandHistory.append(cmdPoint)
            if self.commandHistory.count > self.maxHistoryPoints {
                self.commandHistory.removeFirst(self.commandHistory.count - self.maxHistoryPoints)
            }

            // Update fragmentation chart history
            let point = FragmentationPoint(ratio: fragRatio, wasteBytes: waste)
            self.fragmentationHistory.append(point)
            if self.fragmentationHistory.count > self.maxHistoryPoints {
                self.fragmentationHistory.removeFirst(self.fragmentationHistory.count - self.maxHistoryPoints)
            }
        } catch {
            logger.warning("Failed to fetch live metrics: \(error)")
        }
    }

    private func parseInfoSection(_ raw: String) -> [String: String] {
        var map: [String: String] = [:]
        let lines = raw.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                map[String(parts[0])] = String(parts[1])
            }
        }
        return map
    }

    // MARK: - Parsing Helper

    nonisolated static func parseLine(_ line: String, defaultNode: String) -> MonitorCommandEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var tsStr = ""
        var db = 0
        var client = ""
        var cmd = ""
        var args = ""

        if let openBracket = trimmed.firstIndex(of: "["),
           let closeBracket = trimmed.firstIndex(of: "]"),
           openBracket < closeBracket {
            let tsPart = trimmed[..<openBracket].trimmingCharacters(in: .whitespaces)
            if let d = Double(tsPart) {
                let date = Date(timeIntervalSince1970: d)
                let df = DateFormatter()
                df.dateFormat = "HH:mm:ss.SSS"
                tsStr = df.string(from: date)
            } else {
                tsStr = tsPart
            }

            let insideBracket = trimmed[trimmed.index(after: openBracket)..<closeBracket]
            let bracketParts = insideBracket.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = bracketParts.first, let dbNum = Int(first) {
                db = dbNum
            }
            if bracketParts.count > 1 {
                client = String(bracketParts[1])
            }

            let afterBracket = trimmed[trimmed.index(after: closeBracket)...].trimmingCharacters(in: .whitespaces)
            let tokens = extractQuotedTokens(afterBracket)
            if let first = tokens.first {
                cmd = first.uppercased()
                args = tokens.dropFirst().joined(separator: " ")
            }
        } else {
            cmd = trimmed
        }

        return MonitorCommandEntry(
            timestampString: tsStr.isEmpty ? Date().formatted(date: .omitted, time: .standard) : tsStr,
            node: defaultNode,
            db: db,
            client: client.isEmpty ? "-" : client,
            command: cmd,
            arguments: args
        )
    }

    nonisolated private static func extractQuotedTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        for char in text {
            if char == "\"" {
                if inQuotes {
                    tokens.append(current)
                    current = ""
                    inQuotes = false
                } else {
                    inQuotes = true
                }
            } else if inQuotes {
                current.append(char)
            } else if !char.isWhitespace {
                current.append(char)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
