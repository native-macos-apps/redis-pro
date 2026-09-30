//
//  RedisMonitorModel.swift
//  redis-pro
//
//  Created for Real-time Live Monitor and Server Metrics.
//

import Foundation

public struct MonitorCommandEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let timestampString: String
    public let node: String
    public let db: Int
    public let client: String
    public let command: String
    public let arguments: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        timestampString: String,
        node: String,
        db: Int = 0,
        client: String,
        command: String,
        arguments: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.timestampString = timestampString
        self.node = node
        self.db = db
        self.client = client
        self.command = command
        self.arguments = arguments
    }
}

public struct MetricDataPoint: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let value: Double
    public let secondaryValue: Double?

    public init(id: UUID = UUID(), timestamp: Date = Date(), value: Double, secondaryValue: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.secondaryValue = secondaryValue
    }
}

public struct KeyspaceDbInfo: Identifiable, Sendable {
    public var id: String { dbName }
    public let dbName: String
    public let keys: Int
    public let expires: Int
    public let avgTtl: Int

    public init(dbName: String, keys: Int, expires: Int, avgTtl: Int) {
        self.dbName = dbName
        self.keys = keys
        self.expires = expires
        self.avgTtl = avgTtl
    }
}

public struct RedisServerMetrics: Sendable {
    // Memory
    public var usedMemoryBytes: Int64 = 0
    public var usedMemoryHuman: String = "-"
    public var usedMemoryRssBytes: Int64 = 0
    public var usedMemoryRssHuman: String = "-"
    public var peakMemoryHuman: String = "-"
    public var luaMemoryHuman: String = "-"
    public var maxMemoryHuman: String = "-"
    public var maxMemoryPolicy: String = "-"
    public var fragmentationRatio: Double = 1.0
    public var memAllocator: String = "-"
    public var wasteBytes: Int64 = 0
    public var wasteBytesHuman: String = "-"

    // CPU
    public var cpuSys: Double = 0.0
    public var cpuUser: Double = 0.0
    public var cpuSysChildren: Double = 0.0
    public var cpuUserChildren: Double = 0.0

    // Stats & Throughput
    public var instantOpsPerSec: Int = 0
    public var totalCommandsProcessed: Int = 0
    public var totalConnectionsReceived: Int = 0
    public var instantInputKbps: Double = 0.0
    public var instantOutputKbps: Double = 0.0
    public var rejectedConnections: Int = 0
    public var hitRatio: Double = 100.0
    public var hits: Int = 0
    public var misses: Int = 0
    public var evictedKeys: Int = 0
    public var expiredKeys: Int = 0

    // Clients
    public var connectedClients: Int = 0
    public var blockedClients: Int = 0
    public var maxClients: Int = 10000

    // Persistence & Replication
    public var rdbLastBgsaveStatus: String = "ok"
    public var rdbChangesSinceLastSave: Int = 0
    public var rdbLastBgsaveTimeSec: Int = 0
    public var aofEnabled: Bool = false
    public var role: String = "master"

    // Server
    public var redisVersion: String = "-"
    public var redisMode: String = "standalone"
    public var os: String = "-"
    public var processId: Int = 0
    public var tcpPort: Int = 0
    public var uptimeInSeconds: Int = 0
    public var uptimeHuman: String = "-"

    // Keyspace
    public var totalKeys: Int = 0
    public var keyspaceDbs: [KeyspaceDbInfo] = []

    public init() {}
}

public struct MonitorLiveMetrics: Sendable {
    public var usedMemoryHuman: String = "-"
    public var usedMemoryRssHuman: String = "-"
    public var peakMemoryHuman: String = "-"
    public var fragmentationRatio: Double = 1.0
    public var wasteBytesHuman: String = "-"
    public var cpuSys: Double = 0.0
    public var cpuUser: Double = 0.0
    public var instantOpsPerSec: Int = 0

    public var hitRatio: Double = 100.0
    public var hits: Int = 0
    public var misses: Int = 0
    public var connectedClients: Int = 0
    public var blockedClients: Int = 0
    public var evictedKeys: Int = 0
    public var rdbLastBgsaveStatus: String = "ok"

    public init(
        usedMemoryHuman: String = "-",
        usedMemoryRssHuman: String = "-",
        peakMemoryHuman: String = "-",
        fragmentationRatio: Double = 1.0,
        wasteBytesHuman: String = "-",
        cpuSys: Double = 0.0,
        cpuUser: Double = 0.0,
        instantOpsPerSec: Int = 0,
        hitRatio: Double = 100.0,
        hits: Int = 0,
        misses: Int = 0,
        connectedClients: Int = 0,
        blockedClients: Int = 0,
        evictedKeys: Int = 0,
        rdbLastBgsaveStatus: String = "ok"
    ) {
        self.usedMemoryHuman = usedMemoryHuman
        self.usedMemoryRssHuman = usedMemoryRssHuman
        self.peakMemoryHuman = peakMemoryHuman
        self.fragmentationRatio = fragmentationRatio
        self.wasteBytesHuman = wasteBytesHuman
        self.cpuSys = cpuSys
        self.cpuUser = cpuUser
        self.instantOpsPerSec = instantOpsPerSec
        self.hitRatio = hitRatio
        self.hits = hits
        self.misses = misses
        self.connectedClients = connectedClients
        self.blockedClients = blockedClients
        self.evictedKeys = evictedKeys
        self.rdbLastBgsaveStatus = rdbLastBgsaveStatus
    }
}

public struct CommandHistoryPoint: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let ops: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), ops: Int) {
        self.id = id
        self.timestamp = timestamp
        self.ops = ops
    }
}
