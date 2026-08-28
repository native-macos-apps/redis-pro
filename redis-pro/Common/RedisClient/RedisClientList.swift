//
//  RedisClientList.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - List Operations
extension RedisClient {

    func pageList(_ key: String, page: Page) async throws -> ([RedisListItemModel], Page) {
        logger.info("redis list page, key: \(key), page: \(page)")
        begin()
        defer { complete() }
        
        do {
            var page = page
            let start: Int = (page.current - 1) * page.size
            let r1 = try await llen(key)
            let r2 = try await _lrange(key, start: start, stop: start + page.size - 1)
            let total = r1
            page.total = total
            
            var result: [RedisListItemModel] = []
            for (index, value) in r2.enumerated() {
                result.append(RedisListItemModel(start + index, value ?? ""))
            }
     
            return (result, page)
        } catch {
            handleError(error)
        }
        return ([], page)
    }
    
    func _lrange(_ key: String, start: Int, stop: Int) async throws -> [String?] {
        logger.debug("redis list range, key: \(key)")
        let reply = try await execute(command: "LRANGE", args: [key, String(start), String(stop)])
        return reply.arrayValue?.map { $0.stringValue } ?? []
    }
    
    func ldel(_ key: String, index: Int, value: String) async throws -> Int {
        logger.debug("redis list delete, key: \(key), index:\(index)")
        begin()
        defer { complete() }
        
        do {
            let existValue = try await _lindex(key, index: index)
            guard existValue == value else {
                throw BizError("list value: \(value), index: \(index) have changed, please check!")
            }
            
            try await _lset(key, index: index, value: Const.LIST_VALUE_DELETE_MARK)
            return try await _lrem(key, value: Const.LIST_VALUE_DELETE_MARK)
        } catch {
            handleError(error)
        }
        return 0
    }
    
    private func _lrem(_ key: String, value: String) async throws -> Int {
        let reply = try await execute(command: "LREM", args: [key, "0", value])
        return reply.intValue ?? 0
    }
    
    func lset(_ key: String, index: Int, value: String) async throws {
        begin()
        defer { complete() }
        try await _lset(key, index: index, value: value)
    }
    
    private func _lset(_ key: String, index: Int, value: String) async throws {
        _ = try await execute(command: "LSET", args: [key, String(index), value])
    }
    
    func lpush(_ key: String, value: String) async throws -> Int {
        let reply = try await execute(command: "LPUSH", args: [key, value])
        return reply.intValue ?? 0
    }
    
    func rpush(_ key: String, value: String) async throws -> Int {
        let reply = try await execute(command: "RPUSH", args: [key, value])
        return reply.intValue ?? 0
    }
    
    private func _lindex(_ key: String, index: Int) async throws -> String? {
        let reply = try await execute(command: "LINDEX", args: [key, String(index)])
        return reply.stringValue
    }
    
    private func llen(_ key: String) async throws -> Int {
        logger.debug("redis list length, key: \(key)")
        let reply = try await execute(command: "LLEN", args: [key])
        return reply.intValue ?? 0
    }
}
