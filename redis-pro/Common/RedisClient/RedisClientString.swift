//
//  RedisClientString.swift
//  redis-pro
//
//  Created by chengpan on 2022/8/21.
//

import Foundation

// MARK: - String Operations
extension RedisClient {

    /**
     Set value expire (seconds)
     */
    func set(_ key: String, value: String, ex: Int = -1) async throws {
        logger.info("set value, key:\(key), value:\(value), ex:\(ex)")
        
        if ex == -1 {
            _ = try await execute(command: "SET", args: [key, value])
        } else {
            _ = try await execute(command: "SETEX", args: [key, String(ex), value])
        }
    }
    
    func set(_ key: String, value: String) async throws {
        try await set(key, value: value, ex: -1)
    }
    
    func get(_ key: String) async throws -> String {
        logger.info("get value, key:\(key)")
        let reply = try await execute(command: "GET", args: [key])
        return reply.stringValue ?? Const.EMPTY_STRING
    }
    
    func getRange(_ key: String, start: Int = 0, end: Int) async throws -> String {
        logger.info("get value range, key:\(key), start:\(start), end:\(end)")
        let reply = try await execute(command: "GETRANGE", args: [key, String(start), String(end)])
        return reply.stringValue ?? Const.EMPTY_STRING
    }
    
    func strLen(_ key: String) async throws -> Int {
        logger.info("get value length, key:\(key)")
        let reply = try await execute(command: "STRLEN", args: [key])
        return reply.intValue ?? 0
    }
    
    func del(_ key: String) async throws -> Int {
        return try await del([key])
    }
    
    func del(_ keys: [String]) async throws -> Int {
        self.logger.info("delete keys \(keys)")
        guard !keys.isEmpty else { return 0 }
        let reply = try await execute(command: "DEL", args: keys)
        return reply.intValue ?? 0
    }
    
    func expire(_ key: String, seconds: Int = -1) async throws -> Bool {
        logger.info("set key expire key:\(key), seconds:\(seconds)")
        if seconds < 0 {
            let reply = try await execute(command: "PERSIST", args: [key])
            return reply.intValue == 1
        } else {
            let reply = try await execute(command: "EXPIRE", args: [key, String(seconds)])
            return reply.intValue == 1
        }
    }
    
    func exist(_ key: String) async throws -> Bool {
        logger.info("get key exist: \(key)")
        let reply = try await execute(command: "EXISTS", args: [key])
        return (reply.intValue ?? 0) > 0
    }
    
    func ttl(_ key: String) async throws -> Int {
        logger.info("get ttl key: \(key)")
        let reply = try await execute(command: "TTL", args: [key])
        return reply.intValue ?? -2
    }
    
    func objectEncoding(_ key: String) async throws -> String {
        logger.info("get object encoding, key: \(key)")
        let res: String? = try await self.send("OBJECT", args: ["ENCODING", key])
        return res ?? ""
    }
    
    func getTypes(_ keys: [String]) async throws -> [String: String] {
        return try await withThrowingTaskGroup(of: (String, String).self) { group in
            var typeDict = [String: String]()

            for key in keys {
                group.addTask {
                    let typeStr = try await self.type(key)
                    return (key, typeStr)
                }
            }

            for try await type in group {
                typeDict[type.0] = type.1
            }

            return typeDict
        }
    }
    
    private func type(_ key: String) async throws -> String {
        let reply = try await execute(command: "TYPE", args: [key])
        return reply.stringValue ?? RedisKeyTypeEnum.NONE.rawValue
    }
    
    func rename(_ oldKey: String, newKey: String) async throws -> Bool {
        logger.info("rename key, old key:\(oldKey), new key: \(newKey)")
        let reply = try await execute(command: "RENAMENX", args: [oldKey, newKey])
        let r = reply.intValue == 1
        if !r {
            Task { @MainActor in Messages.show("rename key error, new key: \(newKey) already exists.") }
        }
        
        return r
    }
}
