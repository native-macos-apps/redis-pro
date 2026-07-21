//
//  RedisClient.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/13.
//

import Foundation
import NIO
import Valkey
import Logging
import NIOSSH
import Cocoa

class RedisClient: @unchecked Sendable {
    let logger = Logger(label: "redis-client")
    var redisModel: RedisModel
    var appContext: AppContext? = nil
    
    // Valkey Client
    var valkeyClient: ValkeyClient?
    var backgroundTask: Task<Void, Never>?
    
    // ssh
    var sshChannel: Channel?
    var sshLocalChannel: Channel?
    var sshServer: PortForwardingServer?
    
    // 递归查询每页大小
    let dataScanCount: Int = 2000
    var dataCountScanCount: Int = 2000
    var recursionSize: Int = 2000
    var recursionCountSize: Int = 5000
    
    private var observers = [NSObjectProtocol]()
    private var networkMonitor = NetworkMonitor()
    
    init(_ redisModel: RedisModel) {
        self.redisModel = redisModel
       
        // 监听app退出
        observers.append(
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [self] _ in
                shutdown()
            }
        )
    }
    
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        networkMonitor.stopMonitoring()
        backgroundTask?.cancel()
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
            throw BizError("key: \(key) is not exist!")
        }
    }
    
    // MARK: - Core Send Method
    // This is a bridge for the old _send method. ValkeyClient handles connection pooling internally.
    func _send<R>(_ command: @escaping (ValkeyClient) async throws -> R) async throws -> R {
        guard let client = try await getClient() else {
            throw BizError("Valkey client not initialized")
        }
        return try await command(client)
    }
    
    // MARK: - Client Management
    func getClient() async throws -> ValkeyClient? {
        if let client = valkeyClient {
            return client
        }
        return try await initClient()
    }
    
    func initClient() async throws -> ValkeyClient {
        if self.redisModel.connectionType == RedisConnectionTypeEnum.SSH.rawValue {
            return try await initSSHClient()
        } else {
            return try await initDirectClient()
        }
    }
    
    func initDirectClient() async throws -> ValkeyClient {
        let auth = (redisModel.password.isEmpty && redisModel.username.isEmpty) ? nil : ValkeyClientConfiguration.Authentication(username: redisModel.username, password: redisModel.password)
        let config = ValkeyClientConfiguration(
            authentication: auth,
            databaseNumber: redisModel.database
        )
        
        let client = ValkeyClient(.hostname(redisModel.host, port: redisModel.port), configuration: config, logger: self.logger)
        
        // Start background task for the client
        self.backgroundTask?.cancel()
        self.backgroundTask = Task {
            await client.run()
        }
        
        self.valkeyClient = client
        return client
    }
}

// MARK: - Bridge Types
public protocol ValkeyValueConvertible {
    init(fromValkeyValue token: RESPToken)
}

extension String: ValkeyValueConvertible {
    public init(fromValkeyValue token: RESPToken) {
        switch token.value {
        case .simpleString(let buffer), .bulkString(let buffer), .verbatimString(let buffer):
            self = String(buffer: buffer)
        case .number(let i):
            self = String(i)
        case .double(let d):
            self = String(d)
        case .boolean(let b):
            self = String(b)
        default:
            self = ""
        }
    }
}

extension Int: ValkeyValueConvertible {
    public init(fromValkeyValue token: RESPToken) {
        switch token.value {
        case .number(let i):
            self = Int(i)
        case .simpleString(let buffer), .bulkString(let buffer):
            self = Int(String(buffer: buffer)) ?? 0
        default:
            self = 0
        }
    }
}

extension RESPToken: ValkeyValueConvertible {
    public init(fromValkeyValue token: RESPToken) {
        self = token
    }
}

struct RESPRenderableWrapper: RESPRenderable {
    let base: any RESPRenderable
    var respEntries: Int { base.respEntries }
    func encode(into commandEncoder: inout ValkeyCommandEncoder) {
        base.encode(into: &commandEncoder)
    }
}

// Custom command to support raw commands from the console
struct AnyCommand: ValkeyCommand, @unchecked Sendable {
    typealias Response = RESPToken
    static var name: String { "ANY" }
    var keysAffected: [ValkeyKey] { [] }
    
    let commandName: String
    let args: [any RESPRenderable]
    
    func encode(into commandEncoder: inout ValkeyCommandEncoder) {
        let wrappedArgs = args.map { RESPRenderableWrapper(base: $0) }
        commandEncoder.encodeArray(commandName, wrappedArgs)
    }
    
    static func == (lhs: AnyCommand, rhs: AnyCommand) -> Bool {
        return lhs.commandName == rhs.commandName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(commandName)
    }
}

extension RedisClient {
    // MARK: - Lifecycle
    func close() {
        self.valkeyClient = nil
        self.backgroundTask?.cancel()
        self.backgroundTask = nil
        self.closeSSH()
    }

    func shutdown() {
        close()
    }

    // MARK: - Helper for legacy extensions
    func send<R>(_ command: String, args: [any RESPRenderable] = []) async throws -> R? where R: ValkeyValueConvertible {
        begin()
        defer { complete() }
        
        let client = try await getClient()
        // Use execute with our custom AnyCommand
        do {
            let result = try await client?.execute(AnyCommand(commandName: command, args: args))
            return result.map { R(fromValkeyValue: $0) }
        } catch {
            self.logger.error("Valkey command error: \(error)")
            throw error
        }
    }
}
