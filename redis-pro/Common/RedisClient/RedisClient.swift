//
//  RedisClient.swift
//  redis-pro
//
//  Created by chengpan on 2021/4/13.
//  Migrated to native hiredis (C/C++) engine with Cluster & Sentinel support.
//

import Foundation
import NIO
import NIOSSH
import Logging
import Cocoa

class RedisClient: @unchecked Sendable {
    let logger = Logger(label: "redis-client")
    var redisModel: RedisModel
    var appContext: AppContext? = nil
    
    // Hiredis Client
    var hiredisClient: HiredisClientProtocol?
    
    // SSH
    var sshChannel: Channel?
    var sshLocalChannel: Channel?
    var sshServer: PortForwardingServer?
    var sshTunnel: SSHTunnel?
    
    // Pagination & Scan sizes
    let dataScanCount: Int = 2000
    var dataCountScanCount: Int = 2000
    var recursionSize: Int = 2000
    var recursionCountSize: Int = 5000
    
    private var observers = [NSObjectProtocol]()
    private var networkMonitor = NetworkMonitor()
    
    init(_ redisModel: RedisModel) {
        self.redisModel = redisModel
       
        // Listen to app termination
        observers.append(
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [self] _ in
                shutdown()
            }
        )
    }
    
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        networkMonitor.stopMonitoring()
        close()
    }
    
    func loading(_ bool: Bool) {
        Task { @MainActor in
            bool ? self.appContext?.show() : self.appContext?.hide()
        }
    }
    
    func begin() {
        loading(true)
    }
    
    func complete() {
        loading(false)
    }
    
    func handleError(_ error: Error) {
        loading(false)
        Task { @MainActor in Messages.show(error) }
    }
    
    func assertExist(_ key: String) async throws {
        let exist = try await exist(key)
        if !exist {
            throw BizError("key: \(key) does not exist!")
        }
    }
    
    // MARK: - Core Execution Method
    func execute(command: String, args: [String] = []) async throws -> RedisReply {
        let client = try await getClient()
        return try await client.execute(command: command, args: args)
    }
    
    // MARK: - Client Management
    func getClient() async throws -> HiredisClientProtocol {
        if let client = hiredisClient {
            return client
        }
        return try await initClient()
    }
    
    func initClient() async throws -> HiredisClientProtocol {
        close()
        
        let connectionType = redisModel.connectionType.lowercased()
        
        if connectionType == RedisConnectionTypeEnum.SSH.rawValue {
            return try await initSSHClient()
        } else if connectionType == RedisConnectionTypeEnum.SENTINEL.rawValue {
            return try await initSentinelClient()
        } else if connectionType == RedisConnectionTypeEnum.CLUSTER.rawValue {
            return try await initClusterClient()
        } else {
            return try await initDirectClient()
        }
    }
    
    func initDirectClient() async throws -> HiredisStandaloneClient {
        let client = HiredisStandaloneClient(
            host: redisModel.host,
            port: redisModel.port,
            username: redisModel.username,
            password: redisModel.password,
            database: redisModel.database
        )
        self.hiredisClient = client
        return client
    }
    
    func initSentinelClient() async throws -> HiredisSentinelClient {
        let client = HiredisSentinelClient(
            masterName: redisModel.sentinelMasterName,
            sentinelNodes: redisModel.sentinelNodes,
            fallbackHost: redisModel.host,
            fallbackPort: redisModel.port,
            sentinelPassword: redisModel.sentinelPassword,
            redisUsername: redisModel.username,
            redisPassword: redisModel.password,
            database: redisModel.database
        )
        self.hiredisClient = client
        return client
    }

    func initClusterClient() async throws -> HiredisClusterClient {
        let client = HiredisClusterClient(
            clusterNodes: redisModel.clusterNodes,
            fallbackHost: redisModel.host,
            fallbackPort: redisModel.port,
            username: redisModel.username,
            password: redisModel.password
        )
        self.hiredisClient = client
        return client
    }

    // MARK: - Lifecycle
    func close() {
        let client = self.hiredisClient
        self.hiredisClient = nil
        if let client = client {
            Task {
                await client.close()
            }
        }
        self.closeSSH()
    }

    func shutdown() {
        close()
    }

    // MARK: - Helper for send
    func send<R>(_ command: String, args: [String] = []) async throws -> R? where R: RedisValueConvertible {
        begin()
        defer { complete() }
        
        let client = try await getClient()
        do {
            let reply = try await client.execute(command: command, args: args)
            if reply.isError {
                let err = reply.errorMessage ?? "Redis error"
                self.logger.error("Redis command error: \(err)")
                throw BizError(err)
            }
            if reply.isNil {
                return nil
            }
            return R(fromRedisReply: reply)
        } catch {
            self.logger.error("Command error: \(error)")
            throw error
        }
    }
}
