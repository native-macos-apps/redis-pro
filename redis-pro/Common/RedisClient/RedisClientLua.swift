//
//  RedisClientLua.swift
//  redis-pro
//
//  Created by chengpan on 2022/7/17.
//

import Foundation

// MARK: - Lua Script Operations
extension RedisClient {
    func eval(_ lua: String) async throws -> String {
        logger.info("lua script eval: \(lua)")
        guard lua.count > 3 else {
            return "lua script invalid!"
        }
        begin()
        defer { complete() }
        
        do {
            let trimmedLua = StringHelper.trim(StringHelper.removeStartIgnoreCase(lua, start: "eval"))
            if !StringHelper.startWith(trimmedLua, start: "'") && !StringHelper.startWith(trimmedLua, start: "\"") {
                throw BizError("lua script syntax error, demo: \"return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}\" 2 key1 key2 arg1 arg2")
            }
            
            let separator = trimmedLua[0]
            guard let scriptLastIndex = trimmedLua.lastIndexOf(separator) else {
                throw BizError("lua script syntax error: missing closing separator")
            }
            let start = trimmedLua.index(trimmedLua.startIndex, offsetBy: 1)
            let script = String(trimmedLua[start..<scriptLastIndex])
            
            let argStart = trimmedLua.index(scriptLastIndex, offsetBy: 1)
            let argsStr = StringHelper.trim(String(trimmedLua[argStart...]))
            let argArr = StringHelper.split(argsStr)
            
            logger.info("eval lua script, script: \(script), args: \(argArr)")
            
            // EVAL script numkeys [key ...] [arg ...]
            let reply = try await self.execute(command: "EVAL", args: [script] + argArr)
            return reply.description
        } catch {
            handleError(error)
        }
        
        return "eval error"
    }
    
    @discardableResult
    func eval(_ script: String, keys: [String] = [], args: [String] = []) async throws -> RedisReply {
        return try await self.execute(command: "EVAL", args: [script, String(keys.count)] + keys + args)
    }
    
    @discardableResult
    func evalsha(_ sha1: String, keys: [String] = [], args: [String] = []) async throws -> RedisReply {
        return try await self.execute(command: "EVALSHA", args: [sha1, String(keys.count)] + keys + args)
    }

    func scriptKill() async throws -> String {
        logger.info("lua script kill")
        let reply = try await self.execute(command: "SCRIPT", args: ["KILL"])
        return reply.description
    }
    
    func scriptFlush() async throws {
        logger.info("lua script flush")
        _ = try await self.execute(command: "SCRIPT", args: ["FLUSH"])
    }
}
