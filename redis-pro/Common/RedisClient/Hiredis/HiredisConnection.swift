//
//  HiredisConnection.swift
//  redis-pro
//
//  Created for hiredis integration.
//

import Foundation
import Logging
#if canImport(CHiredis)
import CHiredis
#endif

private let connLogger = Logger(label: "hiredis-conn")

/// Thread-safe box holding the raw `redisContext` pointer.
private final class HiredisContextBox: @unchecked Sendable {
    var rawContext: UnsafeMutablePointer<redisContext>?

    init(context: UnsafeMutablePointer<redisContext>? = nil) {
        self.rawContext = context
    }

    deinit {
        if let ctx = rawContext {
            redisFree(ctx)
        }
    }

    func free() {
        if let ctx = rawContext {
            redisFree(ctx)
            rawContext = nil
        }
    }
}

/// Thread-safe actor managing a single hiredis `redisContext` connection.
public actor HiredisConnection {
    private let box = HiredisContextBox()
    
    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public var database: Int
    public let timeoutSeconds: Double

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
        self.timeoutSeconds = timeoutSeconds
    }

    public var isConnected: Bool {
        guard let ctx = box.rawContext else { return false }
        return ctx.pointee.err == 0
    }

    private static func extractErrorString(from ctx: UnsafeMutablePointer<redisContext>) -> String {
        withUnsafeBytes(of: ctx.pointee.errstr) { rawBuffer in
            if let base = rawBuffer.baseAddress {
                return String(cString: base.assumingMemoryBound(to: CChar.self))
            }
            return "Unknown error"
        }
    }

    /// Establish connection to the Redis server and perform AUTH & SELECT if needed.
    public func connect() throws {
        box.free()

        let tv = timeval(
            tv_sec: Int(timeoutSeconds),
            tv_usec: Int32((timeoutSeconds.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        )

        guard let ctx = redisConnectWithTimeout(host, Int32(port), tv) else {
            throw BizError("Failed to allocate Redis connection context to \(host):\(port)")
        }

        if ctx.pointee.err != 0 {
            let errMsg = HiredisConnection.extractErrorString(from: ctx)
            redisFree(ctx)
            throw BizError("Could not connect to Redis at \(host):\(port): \(errMsg)")
        }

        box.rawContext = ctx

        // Authenticate if password is provided
        if !password.isEmpty {
            let authReply: RedisReply
            if !username.isEmpty {
                authReply = try executeDirect(command: "AUTH", args: [username, password])
            } else {
                authReply = try executeDirect(command: "AUTH", args: [password])
            }
            if authReply.isError {
                let err = authReply.errorMessage ?? "Authentication failed"
                close()
                throw BizError("Redis AUTH error on \(host):\(port): \(err)")
            }
        }

        // Select database if needed
        if database > 0 {
            let selectReply = try executeDirect(command: "SELECT", args: [String(database)])
            if selectReply.isError {
                let err = selectReply.errorMessage ?? "SELECT db failed"
                close()
                throw BizError("Redis SELECT db \(database) error: \(err)")
            }
        }
    }

    /// Execute a command with arguments using binary-safe `redisCommandArgv`.
    public func execute(command: String, args: [String] = []) throws -> RedisReply {
        if box.rawContext == nil || !isConnected {
            try connect()
        }

        do {
            return try executeDirect(command: command, args: args)
        } catch {
            // Attempt one reconnection on broken pipe / EOF
            connLogger.warning("Connection error on \(host):\(port), attempting reconnect: \(error)")
            try connect()
            return try executeDirect(command: command, args: args)
        }
    }

    private func executeDirect(command: String, args: [String]) throws -> RedisReply {
        guard let ctx = box.rawContext else {
            throw BizError("Redis connection not established to \(host):\(port)")
        }

        let tokens = [command] + args
        let argc = Int32(tokens.count)

        // Prepare binary-safe argument pointers and lengths
        var cStrings: [UnsafePointer<CChar>?] = []
        var lens: [Int] = []
        cStrings.reserveCapacity(tokens.count)
        lens.reserveCapacity(tokens.count)

        for token in tokens {
            let cstr = strdup(token)
            cStrings.append(UnsafePointer(cstr))
            lens.append(token.utf8.count)
        }

        defer {
            for ptr in cStrings {
                if let ptr = ptr {
                    free(UnsafeMutableRawPointer(mutating: ptr))
                }
            }
        }

        let rawReply = cStrings.withUnsafeMutableBufferPointer { argvBuffer in
            lens.withUnsafeBufferPointer { lenBuffer in
                redisCommandArgv(
                    ctx,
                    argc,
                    argvBuffer.baseAddress,
                    lenBuffer.baseAddress
                )
            }
        }

        if ctx.pointee.err != 0 {
            let errMsg = HiredisConnection.extractErrorString(from: ctx)
            if let rawReply = rawReply {
                freeReplyObject(rawReply)
            }
            throw BizError("Redis communication error (\(ctx.pointee.err)): \(errMsg)")
        }

        guard let replyPtr = rawReply else {
            throw BizError("Null reply received from Redis command \(command)")
        }

        let cReply = replyPtr.bindMemory(to: redisReply.self, capacity: 1)
        let reply = RedisReply.from(cReply: cReply)
        freeReplyObject(replyPtr)

        return reply
    }

    /// Runs Redis MONITOR command and streams raw reply strings until cancelled or closed.
    public func runMonitor(onLine: @Sendable @escaping (String) -> Void) async throws {
        if box.rawContext == nil || !isConnected {
            try connect()
        }

        // Send initial MONITOR command
        let initReply = try execute(command: "MONITOR", args: [])
        guard initReply.isOK else {
            throw BizError("Failed to start MONITOR: \(initReply)")
        }

        // Loop reading streaming replies
        while !Task.isCancelled {
            guard let activeCtx = box.rawContext else { break }
            var replyPtr: UnsafeMutableRawPointer? = nil
            let res = redisGetReply(activeCtx, &replyPtr)
            if res != REDIS_OK {
                if Task.isCancelled { break }
                // If socket timed out waiting for activity (EAGAIN/EWOULDBLOCK), clear err and continue
                if activeCtx.pointee.err == REDIS_ERR_IO && (errno == EAGAIN || errno == EWOULDBLOCK) {
                    activeCtx.pointee.err = 0
                    continue
                }
                break
            }
            guard let validPtr = replyPtr else { continue }
            let cReply = validPtr.bindMemory(to: redisReply.self, capacity: 1)
            let reply = RedisReply.from(cReply: cReply)
            freeReplyObject(validPtr)

            if let line = reply.stringValue {
                onLine(line)
            }
        }
    }

    /// Explicitly close connection.
    public nonisolated func close() {
        box.free()
    }
}
