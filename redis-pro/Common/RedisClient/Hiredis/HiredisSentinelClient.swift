//
//  HiredisSentinelClient.swift
//  redis-pro
//
//  Created for Redis Sentinel support.
//

import Foundation
import Logging

private let sentinelLogger = Logger(label: "hiredis-sentinel")

/// Hiredis client for Redis Sentinel setups with automatic master discovery and failover handling.
public actor HiredisSentinelClient: HiredisClientProtocol {
    public let masterName: String
    public let sentinelAddresses: [(host: String, port: Int)]
    public let sentinelPassword: String
    public let redisUsername: String
    public let redisPassword: String
    public var database: Int

    private var masterConnection: HiredisConnection?
    private var currentMasterAddr: (host: String, port: Int)?

    public init(
        masterName: String,
        sentinelNodes: String,
        fallbackHost: String = "127.0.0.1",
        fallbackPort: Int = 26379,
        sentinelPassword: String = "",
        redisUsername: String = "",
        redisPassword: String = "",
        database: Int = 0
    ) {
        self.masterName = masterName.isEmpty ? "mymaster" : masterName
        self.sentinelPassword = sentinelPassword
        self.redisUsername = redisUsername
        self.redisPassword = redisPassword
        self.database = database

        var parsedNodes: [(host: String, port: Int)] = []
        let rawNodes = sentinelNodes.components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for raw in rawNodes {
            let parts = raw.components(separatedBy: ":")
            if parts.count == 2, let port = Int(parts[1]) {
                parsedNodes.append((host: parts[0], port: port))
            } else if parts.count == 1 {
                parsedNodes.append((host: parts[0], port: 26379))
            }
        }

        if parsedNodes.isEmpty {
            parsedNodes.append((host: fallbackHost, port: fallbackPort))
        }

        self.sentinelAddresses = parsedNodes
    }

    /// Discover current master address from available Sentinel nodes.
    public func discoverMaster() async throws -> (host: String, port: Int) {
        var lastError: Error?

        for node in sentinelAddresses {
            do {
                sentinelLogger.info("Querying Sentinel at \(node.host):\(node.port) for master '\(masterName)'")
                let sentinelConn = HiredisConnection(
                    host: node.host,
                    port: node.port,
                    password: sentinelPassword,
                    timeoutSeconds: 3.0
                )
                try await sentinelConn.connect()
                let reply = try await sentinelConn.execute(
                    command: "SENTINEL",
                    args: ["get-master-addr-by-name", masterName]
                )
                await sentinelConn.close()

                if let arr = reply.arrayValue, arr.count >= 2,
                   let mHost = arr[0].stringValue,
                   let mPort = arr[1].intValue {
                    sentinelLogger.info("Discovered master '\(masterName)' at \(mHost):\(mPort)")
                    return (mHost, mPort)
                } else if reply.isNil {
                    throw BizError("Sentinel has no master named '\(masterName)'")
                } else if reply.isError {
                    throw BizError("Sentinel error: \(reply.errorMessage ?? "Unknown")")
                }
            } catch {
                sentinelLogger.warning("Sentinel at \(node.host):\(node.port) failed: \(error)")
                lastError = error
            }
        }

        throw lastError ?? BizError("Failed to query any Sentinel node for master '\(masterName)'")
    }

    private func getMasterConnection(forceRefresh: Bool = false) async throws -> HiredisConnection {
        if !forceRefresh, let conn = masterConnection {
            return conn
        }

        let addr = try await discoverMaster()
        let newConn = HiredisConnection(
            host: addr.host,
            port: addr.port,
            username: redisUsername,
            password: redisPassword,
            database: database
        )
        try await newConn.connect()

        self.masterConnection = newConn
        self.currentMasterAddr = addr

        return newConn
    }

    public func execute(command: String, args: [String]) async throws -> RedisReply {
        let conn = try await getMasterConnection()
        do {
            let reply = try await conn.execute(command: command, args: args)
            // Handle READONLY error if failover occurred and this node is now a replica
            if reply.isError, let msg = reply.errorMessage, msg.contains("READONLY") {
                sentinelLogger.warning("Master is now READONLY, triggering rediscovery...")
                let refreshedConn = try await getMasterConnection(forceRefresh: true)
                return try await refreshedConn.execute(command: command, args: args)
            }
            return reply
        } catch {
            sentinelLogger.warning("Master execution failed: \(error), attempting Sentinel failover reconnect...")
            let refreshedConn = try await getMasterConnection(forceRefresh: true)
            return try await refreshedConn.execute(command: command, args: args)
        }
    }

    public func selectDB(_ database: Int) async throws -> Bool {
        self.database = database
        let conn = try await getMasterConnection()
        let reply = try await conn.execute(command: "SELECT", args: [String(database)])
        return reply.isOK
    }

    public func ping() async throws -> Bool {
        let conn = try await getMasterConnection()
        let reply = try await conn.execute(command: "PING", args: [])
        return reply.stringValue?.uppercased() == "PONG" || reply.isOK
    }

    public func close() async {
        let conn = masterConnection
        masterConnection = nil
        if let conn = conn {
            await conn.close()
        }
    }
}
