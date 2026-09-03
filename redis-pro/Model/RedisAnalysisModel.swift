//
//  RedisAnalysisModel.swift
//  redis-pro
//
//  Created for Real-time Memory Analysis.
//

import Foundation

public enum RankByOption: String, CaseIterable, Identifiable, Sendable {
    case size = "Size"
    case hottest = "Hottest"
    case coldest = "Coldest"

    public var id: String { rawValue }
}

public struct FragmentationPoint: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let ratio: Double
    public let wasteBytes: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), ratio: Double, wasteBytes: Int) {
        self.id = id
        self.timestamp = timestamp
        self.ratio = ratio
        self.wasteBytes = wasteBytes
    }
}

public struct TTLBucket: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public var count: Int
    public var estimatedCount: Int
    public let sortOrder: Int

    public init(id: UUID = UUID(), label: String, count: Int = 0, estimatedCount: Int = 0, sortOrder: Int) {
        self.id = id
        self.label = label
        self.count = count
        self.estimatedCount = estimatedCount
        self.sortOrder = sortOrder
    }
}

public struct AnalysisPrefixGroup: Identifiable, Sendable {
    public let id: UUID
    public let prefix: String
    public var sampledKeyCount: Int
    public var estimatedKeyCount: Int
    public var sampledMemoryBytes: Int
    public var estimatedMemoryBytes: Int
    public var avgTTLSeconds: Double?
    public var permKeysCount: Int
    public var types: [String]

    public init(
        id: UUID = UUID(),
        prefix: String,
        sampledKeyCount: Int,
        estimatedKeyCount: Int,
        sampledMemoryBytes: Int,
        estimatedMemoryBytes: Int,
        avgTTLSeconds: Double? = nil,
        permKeysCount: Int,
        types: [String]
    ) {
        self.id = id
        self.prefix = prefix
        self.sampledKeyCount = sampledKeyCount
        self.estimatedKeyCount = estimatedKeyCount
        self.sampledMemoryBytes = sampledMemoryBytes
        self.estimatedMemoryBytes = estimatedMemoryBytes
        self.avgTTLSeconds = avgTTLSeconds
        self.permKeysCount = permKeysCount
        self.types = types
    }

    public var formattedMemory: String {
        formatBytes(estimatedMemoryBytes)
    }

    public var formattedKeyCount: String {
        "~\(estimatedKeyCount.formatted())"
    }

    public var formattedPermKeys: String {
        "~\(permKeysCount.formatted())"
    }

    public var formattedAvgTTL: String {
        guard let avg = avgTTLSeconds, avg > 0 else {
            return "Perm"
        }
        if avg < 60 {
            return "\(Int(avg))s"
        } else if avg < 3600 {
            return "\(Int(avg / 60))m"
        } else if avg < 86400 {
            let h = Int(avg / 3600)
            let m = Int((avg.truncatingRemainder(dividingBy: 3600)) / 60)
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            let d = Int(avg / 86400)
            let h = Int((avg.truncatingRemainder(dividingBy: 86400)) / 3600)
            return h > 0 ? "\(d)d \(h)h" : "\(d)d"
        }
    }

    public var typesDisplay: String {
        if types.isEmpty { return "-" }
        return types.joined(separator: ", ")
    }

    private func formatBytes(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b < 1024 {
            return "\(bytes)B"
        } else if b < 1024 * 1024 {
            return String(format: "~%.2fkB", b / 1024)
        } else if b < 1024 * 1024 * 1024 {
            return String(format: "~%.2fMB", b / (1024 * 1024))
        } else {
            return String(format: "~%.2fGB", b / (1024 * 1024 * 1024))
        }
    }
}
