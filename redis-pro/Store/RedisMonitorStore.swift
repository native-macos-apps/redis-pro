//
//  RedisMonitorStore.swift
//  redis-pro
//
//  Created for Real-time Command Log Stream and Multi-condition Filtering.
//

import Foundation
import SwiftUI
import Logging

private let logger = Logger(label: "redis-pro.RedisMonitorStore")

@Observable
@MainActor
final class RedisMonitorViewModel {
    var isMonitoring: Bool = false
    var entries: [MonitorCommandEntry] = []

    // Filter bar conditions
    var filterDb: String = "All"
    var filterCommand: String = ""
    var filterClient: String = ""
    var filterKeyword: String = ""

    // Options and selection
    var isAutoScrollEnabled: Bool = true
    var selectedEntry: MonitorCommandEntry? = nil

    private let redisInstance: RedisInstanceModel
    private var monitorConnection: HiredisConnection?
    private var monitorTask: Task<Void, Never>?
    private let maxEntries = 5000

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("RedisMonitorViewModel initialized")
    }

    static let standardDbs: [String] = ["All"] + (0...15).map(String.init)
    var availableDbs: [String] {
        Self.standardDbs
    }

    var hasActiveFilters: Bool {
        filterDb != "All" ||
        !filterCommand.trimmingCharacters(in: .whitespaces).isEmpty ||
        !filterClient.trimmingCharacters(in: .whitespaces).isEmpty ||
        !filterKeyword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func resetFilters() {
        filterDb = "All"
        filterCommand = ""
        filterClient = ""
        filterKeyword = ""
    }

    var filteredEntries: [MonitorCommandEntry] {
        let clientKw = filterClient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let keyKw = filterKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cmdKw = filterCommand.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let dbFilter = filterDb

        return entries.filter { entry in
            // DB filter (All or 0..15)
            if dbFilter != "All" {
                if String(entry.db) != dbFilter { return false }
            }

            // Command filter
            if !cmdKw.isEmpty {
                if !entry.command.uppercased().contains(cmdKw) { return false }
            }

            // Client filter
            if !clientKw.isEmpty {
                if !entry.client.lowercased().contains(clientKw) { return false }
            }

            // Keyword / Arguments filter
            if !keyKw.isEmpty {
                if !entry.arguments.lowercased().contains(keyKw) &&
                   !entry.command.lowercased().contains(keyKw) {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        startMonitoring()
    }

    func onDisappear() {
        stopMonitoring()
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
        selectedEntry = nil
    }

    func stop() {
        stopMonitoring()
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
