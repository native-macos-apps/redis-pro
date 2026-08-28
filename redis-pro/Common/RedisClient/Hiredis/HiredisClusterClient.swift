//
//  HiredisClusterClient.swift
//  redis-pro
//
//  Created for Redis Cluster support.
//

import Foundation
import Logging

private let clusterLogger = Logger(label: "hiredis-cluster")

/// Hiredis client for Redis Cluster with 16384-slot CRC16 routing, topology discovery,
/// and automatic handling of MOVED / ASK redirections.
public actor HiredisClusterClient: HiredisClientProtocol {
    public let seedAddresses: [(host: String, port: Int)]
    public let username: String
    public let password: String

    private var slotsMap: [Int: String] = [:] // slot -> "host:port"
    private var masterNodes: Set<String> = [] // Set of "host:port"
    private var connections: [String: HiredisConnection] = [:] // "host:port" -> HiredisConnection

    public init(
        clusterNodes: String,
        fallbackHost: String = "127.0.0.1",
        fallbackPort: Int = 6379,
        username: String = "",
        password: String = ""
    ) {
        self.username = username
        self.password = password

        var parsedNodes: [(host: String, port: Int)] = []
        let rawNodes = clusterNodes.components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for raw in rawNodes {
            let parts = raw.components(separatedBy: ":")
            if parts.count == 2, let port = Int(parts[1]) {
                parsedNodes.append((host: parts[0], port: port))
            } else if parts.count == 1 {
                parsedNodes.append((host: parts[0], port: 6379))
            }
        }

        if parsedNodes.isEmpty {
            parsedNodes.append((host: fallbackHost, port: fallbackPort))
        }

        self.seedAddresses = parsedNodes
    }

    // MARK: - Connection Management

    private func getConnection(for address: String) -> HiredisConnection {
        if let existing = connections[address] {
            return existing
        }

        let parts = address.components(separatedBy: ":")
        let host = parts.count > 0 ? parts[0] : "127.0.0.1"
        let port = parts.count > 1 ? (Int(parts[1]) ?? 6379) : 6379

        let conn = HiredisConnection(
            host: host,
            port: port,
            username: username,
            password: password,
            database: 0
        )
        connections[address] = conn
        return conn
    }

    /// Discover cluster slots mapping using CLUSTER SLOTS or CLUSTER NODES.
    public func refreshSlots() async throws {
        var allCandidateAddresses: [String] = []

        for seed in seedAddresses {
            allCandidateAddresses.append("\(seed.host):\(seed.port)")
        }
        for node in masterNodes {
            if !allCandidateAddresses.contains(node) {
                allCandidateAddresses.append(node)
            }
        }

        var refreshed = false
        var lastError: Error?

        for addr in allCandidateAddresses {
            do {
                let conn = getConnection(for: addr)
                let reply = try await conn.execute(command: "CLUSTER", args: ["SLOTS"])

                if let slotRanges = reply.arrayValue, !slotRanges.isEmpty {
                    var newSlotsMap: [Int: String] = [:]
                    var newMasters: Set<String> = []

                    for rangeItem in slotRanges {
                        guard let rangeArr = rangeItem.arrayValue, rangeArr.count >= 3,
                              let startSlot = rangeArr[0].intValue,
                              let endSlot = rangeArr[1].intValue,
                              let masterInfo = rangeArr[2].arrayValue, masterInfo.count >= 2,
                              let masterHost = masterInfo[0].stringValue,
                              let masterPort = masterInfo[1].intValue else {
                            continue
                        }

                        // If master returns empty host or loopback name, normalize if needed
                        let actualHost = (masterHost.isEmpty || masterHost == "127.0.0.1" && addr.components(separatedBy: ":")[0] != "127.0.0.1")
                            ? addr.components(separatedBy: ":")[0]
                            : masterHost
                        let masterAddr = "\(actualHost):\(masterPort)"
                        newMasters.insert(masterAddr)

                        for slot in startSlot...endSlot {
                            newSlotsMap[slot] = masterAddr
                        }
                    }

                    if !newSlotsMap.isEmpty {
                        self.slotsMap = newSlotsMap
                        self.masterNodes = newMasters
                        clusterLogger.info("Cluster slots refreshed: mapped \(newSlotsMap.count) slots across \(newMasters.count) master nodes")
                        refreshed = true
                        break
                    }
                }
            } catch {
                clusterLogger.warning("Failed to refresh cluster slots from \(addr): \(error)")
                lastError = error
            }
        }

        if !refreshed {
            throw lastError ?? BizError("Failed to discover cluster topology from any seed node.")
        }
    }

    // MARK: - Key Extraction

    private func extractKey(command: String, args: [String]) -> String? {
        guard !args.isEmpty else { return nil }
        let cmd = command.uppercased()

        if cmd == "EVAL" || cmd == "EVALSHA" {
            // EVAL script numkeys key1 ...
            if args.count >= 3, let numKeys = Int(args[1]), numKeys > 0 {
                return args[2]
            }
            return nil
        }

        // Standard commands where args[0] is the key
        let standardKeyCommands: Set<String> = [
            "GET", "SET", "SETEX", "SETNX", "GETRANGE", "STRLEN", "DEL", "EXPIRE",
            "PEXPIRE", "PERSIST", "TTL", "PTTL", "EXISTS", "TYPE", "OBJECT", "RENAME",
            "HSET", "HGET", "HDEL", "HLEN", "HEXISTS", "HGETALL", "HINCRBY", "HKEYS", "HVALS", "HSCAN",
            "LPUSH", "RPUSH", "LPOP", "RPOP", "LLEN", "LRANGE", "LINDEX", "LSET", "LREM",
            "SADD", "SREM", "SMEMBERS", "SISMEMBER", "SCARD", "SSCAN",
            "ZADD", "ZREM", "ZSCORE", "ZCARD", "ZRANGE", "ZREVRANGE", "ZSCAN", "ZINCRBY",
            "GEOPOS", "GEOADD", "GEOSEARCH", "MEMORY"
        ]

        if standardKeyCommands.contains(cmd) {
            return args[0]
        }

        return args.first
    }

    // MARK: - Command Execution

    public func execute(command: String, args: [String]) async throws -> RedisReply {
        let cmd = command.uppercased()

        // 1. Multi-node broadcast commands
        if cmd == "DBSIZE" {
            return try await executeDBSizeAcrossMasters()
        } else if cmd == "FLUSHDB" || cmd == "FLUSHALL" {
            return try await executeBroadcastAcrossMasters(command: command, args: args)
        } else if cmd == "CLIENT" && args.first?.uppercased() == "LIST" {
            return try await executeClientListAcrossMasters()
        } else if cmd == "INFO" {
            return try await executeInfoAcrossMasters(args: args)
        }

        // 2. Single-node execution with slot routing
        if slotsMap.isEmpty {
            try await refreshSlots()
        }

        var targetAddr: String?
        if let key = extractKey(command: command, args: args) {
            let slot = CRC16.slot(for: key)
            targetAddr = slotsMap[slot]
        }

        if targetAddr == nil {
            targetAddr = masterNodes.first ?? seedAddresses.map { "\($0.host):\($0.port)" }.first
        }

        guard let chosenAddr = targetAddr else {
            throw BizError("No available cluster node to execute command \(command)")
        }

        return try await executeWithRedirection(command: command, args: args, targetAddr: chosenAddr, maxHops: 5)
    }

    private func executeWithRedirection(
        command: String,
        args: [String],
        targetAddr: String,
        maxHops: Int
    ) async throws -> RedisReply {
        guard maxHops > 0 else {
            throw BizError("Cluster redirection loop detected for command \(command)")
        }

        let conn = getConnection(for: targetAddr)
        let reply = try await conn.execute(command: command, args: args)

        if reply.isError, let err = reply.errorMessage {
            // Handle MOVED redirect: -MOVED <slot> <ip:port>
            if err.hasPrefix("MOVED") {
                let parts = err.components(separatedBy: " ")
                if parts.count >= 3, let slot = Int(parts[1]) {
                    let newAddr = parts[2]
                    clusterLogger.info("Received MOVED redirect for slot \(slot) to \(newAddr)")
                    slotsMap[slot] = newAddr
                    masterNodes.insert(newAddr)

                    return try await executeWithRedirection(
                        command: command,
                        args: args,
                        targetAddr: newAddr,
                        maxHops: maxHops - 1
                    )
                }
            }

            // Handle ASK redirect: -ASK <slot> <ip:port>
            if err.hasPrefix("ASK") {
                let parts = err.components(separatedBy: " ")
                if parts.count >= 3 {
                    let askAddr = parts[2]
                    clusterLogger.info("Received ASK redirect to \(askAddr)")
                    let askConn = getConnection(for: askAddr)
                    _ = try await askConn.execute(command: "ASKING", args: [])
                    return try await askConn.execute(command: command, args: args)
                }
            }
        }

        return reply
    }

    // MARK: - Multi-node Helpers

    private func executeDBSizeAcrossMasters() async throws -> RedisReply {
        if masterNodes.isEmpty { try await refreshSlots() }
        var totalSize: Int64 = 0

        for master in masterNodes {
            do {
                let conn = getConnection(for: master)
                let reply = try await conn.execute(command: "DBSIZE", args: [])
                if let count = reply.intValue {
                    totalSize += Int64(count)
                }
            } catch {
                clusterLogger.warning("DBSIZE on master \(master) failed: \(error)")
            }
        }
        return .integer(totalSize)
    }

    private func executeBroadcastAcrossMasters(command: String, args: [String]) async throws -> RedisReply {
        if masterNodes.isEmpty { try await refreshSlots() }
        for master in masterNodes {
            let conn = getConnection(for: master)
            _ = try await conn.execute(command: command, args: args)
        }
        return .status("OK")
    }

    private func executeClientListAcrossMasters() async throws -> RedisReply {
        if masterNodes.isEmpty { try await refreshSlots() }
        var combinedList = ""
        for master in masterNodes {
            do {
                let conn = getConnection(for: master)
                let reply = try await conn.execute(command: "CLIENT", args: ["LIST"])
                if let str = reply.stringValue {
                    combinedList += str + "\n"
                }
            } catch {
                clusterLogger.warning("CLIENT LIST on master \(master) failed: \(error)")
            }
        }
        return .string(combinedList.trimmingCharacters(in: .newlines))
    }

    private func executeInfoAcrossMasters(args: [String]) async throws -> RedisReply {
        if masterNodes.isEmpty { try await refreshSlots() }
        var combinedInfo = ""
        for master in masterNodes {
            do {
                let conn = getConnection(for: master)
                let reply = try await conn.execute(command: "INFO", args: args)
                if let str = reply.stringValue {
                    combinedInfo += "\n# Node: \(master)\n" + str + "\n"
                }
            } catch {
                clusterLogger.warning("INFO on master \(master) failed: \(error)")
            }
        }
        return .string(combinedInfo)
    }

    // MARK: - Lifecycle

    public func selectDB(_ database: Int) async throws -> Bool {
        if database != 0 {
            throw BizError("Redis Cluster only supports database 0.")
        }
        return true
    }

    public func ping() async throws -> Bool {
        if masterNodes.isEmpty {
            try await refreshSlots()
        }
        guard let master = masterNodes.first else { return false }
        let conn = getConnection(for: master)
        let reply = try await conn.execute(command: "PING", args: [])
        return reply.stringValue?.uppercased() == "PONG" || reply.isOK
    }

    public func close() async {
        let conns = Array(connections.values)
        connections.removeAll()
        slotsMap.removeAll()
        masterNodes.removeAll()

        for conn in conns {
            await conn.close()
        }
    }
}
