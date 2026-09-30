//
//  RedisMetricsStore.swift
//  redis-pro
//
//  Created for Real-time Server Metrics and Visual Performance Charts.
//

import Foundation
import SwiftUI
import Logging

private let logger = Logger(label: "redis-pro.RedisMetricsStore")

@Observable
@MainActor
final class RedisMetricsViewModel {
    var isPolling: Bool = false
    var pollInterval: Double = 2.0 // 1.0, 2.0, 5.0 seconds
    var latestMetrics: RedisServerMetrics = RedisServerMetrics()

    // Chart histories (up to maxHistoryPoints)
    var opsHistory: [MetricDataPoint] = []
    var memoryHistory: [MetricDataPoint] = []
    var hitRatioHistory: [MetricDataPoint] = []
    var clientsHistory: [MetricDataPoint] = []
    var networkHistory: [MetricDataPoint] = []
    var fragHistory: [MetricDataPoint] = []
    var cpuHistory: [MetricDataPoint] = []

    private let redisInstance: RedisInstanceModel
    private var pollingTask: Task<Void, Never>?
    private let maxHistoryPoints = 60

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("RedisMetricsViewModel initialized")
    }

    // MARK: - Lifecycle

    func onAppear() {
        startPolling()
    }

    func onDisappear() {
        stopPolling()
    }

    func togglePolling() {
        if isPolling {
            stopPolling()
        } else {
            startPolling()
        }
    }

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true

        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchMetrics()
                guard let interval = self?.pollInterval else { break }
                let nanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    func stopPolling() {
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshNow() {
        Task {
            await fetchMetrics()
        }
    }

    // MARK: - Data Fetching

    func fetchMetrics() async {
        do {
            let client = redisInstance.getClient()
            let infoReply = try await client.execute(command: "INFO", args: [])

            guard let rawInfo = infoReply.stringValue else { return }
            let parsed = parseAllInfo(rawInfo)

            var metrics = RedisServerMetrics()
            let now = Date()

            // Server Section
            metrics.redisVersion = parsed["redis_version"] ?? "-"
            metrics.redisMode = parsed["redis_mode"] ?? "standalone"
            metrics.os = parsed["os"] ?? "-"
            metrics.processId = Int(parsed["process_id"] ?? "0") ?? 0
            metrics.tcpPort = Int(parsed["tcp_port"] ?? "0") ?? 0
            let uptimeSec = Int(parsed["uptime_in_seconds"] ?? "0") ?? 0
            metrics.uptimeInSeconds = uptimeSec
            metrics.uptimeHuman = formatUptime(uptimeSec)
            metrics.role = parsed["role"] ?? "master"

            // Memory Section
            metrics.usedMemoryHuman = parsed["used_memory_human"] ?? "-"
            metrics.usedMemoryRssHuman = parsed["used_memory_rss_human"] ?? "-"
            metrics.peakMemoryHuman = parsed["used_memory_peak_human"] ?? "-"
            metrics.luaMemoryHuman = parsed["used_memory_lua_human"] ?? "-"
            metrics.maxMemoryHuman = parsed["maxmemory_human"] ?? "-"
            metrics.maxMemoryPolicy = parsed["maxmemory_policy"] ?? "-"
            metrics.memAllocator = parsed["mem_allocator"] ?? "-"

            let usedBytes = Int64(parsed["used_memory"] ?? "0") ?? 0
            let rssBytes = Int64(parsed["used_memory_rss"] ?? "0") ?? 0
            metrics.usedMemoryBytes = usedBytes
            metrics.usedMemoryRssBytes = rssBytes

            let waste = max(0, rssBytes - usedBytes)
            metrics.wasteBytes = waste
            metrics.wasteBytesHuman = ByteCountFormatter.string(fromByteCount: waste, countStyle: .binary)

            if let fragStr = parsed["mem_fragmentation_ratio"], let frag = Double(fragStr) {
                metrics.fragmentationRatio = frag
            }

            // CPU Section
            metrics.cpuSys = Double(parsed["used_cpu_sys"] ?? "0") ?? 0.0
            metrics.cpuUser = Double(parsed["used_cpu_user"] ?? "0") ?? 0.0
            metrics.cpuSysChildren = Double(parsed["used_cpu_sys_children"] ?? "0") ?? 0.0
            metrics.cpuUserChildren = Double(parsed["used_cpu_user_children"] ?? "0") ?? 0.0

            // Stats Section
            metrics.instantOpsPerSec = Int(parsed["instantaneous_ops_per_sec"] ?? "0") ?? 0
            metrics.totalCommandsProcessed = Int(parsed["total_commands_processed"] ?? "0") ?? 0
            metrics.totalConnectionsReceived = Int(parsed["total_connections_received"] ?? "0") ?? 0
            metrics.instantInputKbps = Double(parsed["instantaneous_input_kbps"] ?? "0") ?? 0.0
            metrics.instantOutputKbps = Double(parsed["instantaneous_output_kbps"] ?? "0") ?? 0.0
            metrics.rejectedConnections = Int(parsed["rejected_connections"] ?? "0") ?? 0

            let hits = Int(parsed["keyspace_hits"] ?? "0") ?? 0
            let misses = Int(parsed["keyspace_misses"] ?? "0") ?? 0
            metrics.hits = hits
            metrics.misses = misses
            let totalHitsMisses = hits + misses
            metrics.hitRatio = totalHitsMisses > 0 ? (Double(hits) / Double(totalHitsMisses)) * 100.0 : 100.0

            metrics.evictedKeys = Int(parsed["evicted_keys"] ?? "0") ?? 0
            metrics.expiredKeys = Int(parsed["expired_keys"] ?? "0") ?? 0

            // Clients Section
            metrics.connectedClients = Int(parsed["connected_clients"] ?? "0") ?? 0
            metrics.blockedClients = Int(parsed["blocked_clients"] ?? "0") ?? 0
            metrics.maxClients = Int(parsed["maxclients"] ?? "10000") ?? 10000

            // Persistence Section
            metrics.rdbLastBgsaveStatus = parsed["rdb_last_bgsave_status"] ?? "ok"
            metrics.rdbChangesSinceLastSave = Int(parsed["rdb_changes_since_last_save"] ?? "0") ?? 0
            metrics.rdbLastBgsaveTimeSec = Int(parsed["rdb_last_bgsave_time_sec"] ?? "0") ?? 0
            metrics.aofEnabled = (parsed["aof_enabled"] ?? "0") == "1"

            // Keyspace Section
            var dbs: [KeyspaceDbInfo] = []
            var totalKeysCount = 0
            for (k, v) in parsed {
                if k.hasPrefix("db") && k.count <= 5 {
                    // db0:keys=10,expires=0,avg_ttl=0
                    let components = v.components(separatedBy: ",")
                    var kCount = 0
                    var expCount = 0
                    var ttlVal = 0
                    for comp in components {
                        let parts = comp.split(separator: "=", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            if parts[0] == "keys" { kCount = Int(parts[1]) ?? 0 }
                            else if parts[0] == "expires" { expCount = Int(parts[1]) ?? 0 }
                            else if parts[0] == "avg_ttl" { ttlVal = Int(parts[1]) ?? 0 }
                        }
                    }
                    totalKeysCount += kCount
                    dbs.append(KeyspaceDbInfo(dbName: k.uppercased(), keys: kCount, expires: expCount, avgTtl: ttlVal))
                }
            }
            dbs.sort { $0.dbName < $1.dbName }
            metrics.totalKeys = totalKeysCount
            metrics.keyspaceDbs = dbs

            self.latestMetrics = metrics

            // Append to chart histories
            appendPoint(&opsHistory, MetricDataPoint(timestamp: now, value: Double(metrics.instantOpsPerSec)))

            let usedMB = Double(usedBytes) / (1024.0 * 1024.0)
            let rssMB = Double(rssBytes) / (1024.0 * 1024.0)
            appendPoint(&memoryHistory, MetricDataPoint(timestamp: now, value: usedMB, secondaryValue: rssMB))

            appendPoint(&hitRatioHistory, MetricDataPoint(timestamp: now, value: metrics.hitRatio))

            appendPoint(&clientsHistory, MetricDataPoint(
                timestamp: now,
                value: Double(metrics.connectedClients),
                secondaryValue: Double(metrics.blockedClients)
            ))

            appendPoint(&networkHistory, MetricDataPoint(
                timestamp: now,
                value: metrics.instantInputKbps,
                secondaryValue: metrics.instantOutputKbps
            ))

            let wasteMB = Double(waste) / (1024.0 * 1024.0)
            appendPoint(&fragHistory, MetricDataPoint(
                timestamp: now,
                value: metrics.fragmentationRatio,
                secondaryValue: wasteMB
            ))

            appendPoint(&cpuHistory, MetricDataPoint(
                timestamp: now,
                value: metrics.cpuSys,
                secondaryValue: metrics.cpuUser
            ))

        } catch {
            logger.warning("Failed to fetch Redis INFO metrics: \(error)")
        }
    }

    private func appendPoint(_ array: inout [MetricDataPoint], _ pt: MetricDataPoint) {
        array.append(pt)
        if array.count > maxHistoryPoints {
            array.removeFirst(array.count - maxHistoryPoints)
        }
    }

    private func parseAllInfo(_ raw: String) -> [String: String] {
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

    private func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m \(seconds % 60)s"
        }
    }
}
