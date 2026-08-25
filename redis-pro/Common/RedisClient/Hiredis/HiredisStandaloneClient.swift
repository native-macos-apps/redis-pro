//
//  HiredisStandaloneClient.swift
//  redis-pro
//
//  Created for standalone and SSH Redis connections.
//

import Foundation
import Logging

public protocol HiredisClientProtocol: Sendable {
    func execute(command: String, args: [String]) async throws -> RedisReply
    func selectDB(_ database: Int) async throws -> Bool
    func ping() async throws -> Bool
    func close() async
}

/// Hiredis client for Standalone / Direct / SSH Tunnel Redis connections.
public actor HiredisStandaloneClient: HiredisClientProtocol {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public var database: Int

    private let connection: HiredisConnection

    public init(
        host: String,
        port: Int,
        username: String = "",
        password: String = "",
        database: Int = 0,
        timeoutSeconds: Double = 5.0
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.connection = HiredisConnection(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            timeoutSeconds: timeoutSeconds
        )
    }

    public func execute(command: String, args: [String]) async throws -> RedisReply {
        return try await connection.execute(command: command, args: args)
    }

    public func selectDB(_ database: Int) async throws -> Bool {
        self.database = database
        let reply = try await connection.execute(command: "SELECT", args: [String(database)])
        return reply.isOK
    }

    public func ping() async throws -> Bool {
        let reply = try await connection.execute(command: "PING", args: [])
        return reply.stringValue?.uppercased() == "PONG" || reply.isOK
    }

    public func close() async {
        await connection.close()
    }
}
