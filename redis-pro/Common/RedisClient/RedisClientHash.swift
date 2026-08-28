//
//  RedisClientHash.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - Hash Operations
extension RedisClient {
    
    func pageHash(_ key: String, page: Page) async throws -> ([RedisHashEntryModel], Page) {
        logger.info("redis hash field page scan, key: \(key), page: \(page)")
        
        begin()
        defer { complete() }
        
        do {
            var page = page
            try await assertExist(key)
            let isScan = isScan(page.keywords)
            var r: [RedisHashEntryModel] = []
            
            if isScan {
                let match = page.keywords.isEmpty ? nil : page.keywords
                let pageData: [(String, String)] = try await _hashPageScan(key, page: page)
                r = pageData.map { RedisHashEntryModel(field: $0.0, value: $0.1) }
                
                let total = try await _hashCountScan(key, keywords: match)
                page.total = total
            } else {
                let value = try await _hget(key, field: page.keywords)
                if let value = value, !value.isEmpty {
                    r.append(RedisHashEntryModel(field: page.keywords, value: value))
                    page.total = 1
                }
            }
            return (r, page)
        } catch {
            handleError(error)
        }
        return ([], page)
    }
    
    func hset(key: String, field: String, value: String) async throws -> Int {
        let reply = try await execute(command: "HSET", args: [key, field, value])
        return reply.intValue ?? 0
    }
    
    func hdel(key: String, fields: [String]) async throws -> Int {
        guard !fields.isEmpty else { return 0 }
        let reply = try await execute(command: "HDEL", args: [key] + fields)
        return reply.intValue ?? 0
    }
    
    private func _hashCountScan(_ key: String, keywords: String?) async throws -> Int {
        if isMatchAll(keywords ?? "") {
            logger.info("keywords is match all, use hlen...")
            return try await hlen(key: key)
        }
        
        var cursor: Int = 0
        var count: Int = 0
        
        while true {
            let res = try await hscan(key: key, cursor: cursor, pattern: keywords, count: dataCountScanCount)
            logger.info("loop scan page, current cursor: \(res.0), total count: \(count)")
            cursor = res.0
            count = count + res.1.count
            
            if cursor == 0 {
                break
            }
        }
        return count
    }
    
    private func _hashPageScan(_ key: String, page: Page) async throws -> [(String, String)] {
        let keywords = page.keywords.isEmpty ? nil : page.keywords
        var end: Int = page.end
        var cursor: Int = 0
        var entries: [(String, String)] = []
        
        while true {
            let res = try await hscan(key: key, cursor: cursor, pattern: keywords, count: dataScanCount)
            logger.info("hash loop scan page, current cursor: \(res.0), total count: \(entries.count)")
            cursor = res.0
            entries = entries + res.1
            
            if cursor == 0 || entries.count >= end {
                break
            }
        }
        
        let start = page.start
        if start >= entries.count {
            return []
        }
        
        end = min(end, entries.count)
        return Array(entries[start..<end])
    }
    
    private func hlen(key: String) async throws -> Int {
        let reply = try await execute(command: "HLEN", args: [key])
        return reply.intValue ?? 0
    }
    
    func hscan(key: String, cursor: Int, pattern: String?, count: Int?) async throws -> (Int, [(String, String)]) {
        var args = [key, String(cursor)]
        if let pattern = pattern, !pattern.isEmpty {
            args += ["MATCH", pattern]
        }
        if let count = count {
            args += ["COUNT", String(count)]
        }
        
        let reply = try await execute(command: "HSCAN", args: args)
        guard let arr = reply.arrayValue, arr.count >= 2 else {
            return (0, [])
        }
        
        let newCursor = arr[0].intValue ?? 0
        var elements: [(String, String)] = []
        
        if let items = arr[1].arrayValue {
            var i = 0
            while i + 1 < items.count {
                if let k = items[i].stringValue, let v = items[i + 1].stringValue {
                    elements.append((k, v))
                }
                i += 2
            }
        } else if let map = arr[1].mapValue {
            for (k, v) in map {
                if let keyStr = k.stringValue, let valStr = v.stringValue {
                    elements.append((keyStr, valStr))
                }
            }
        }
        
        return (newCursor, elements)
    }
    
    private func _hget(_ key: String, field: String) async throws -> String? {
        let reply = try await execute(command: "HGET", args: [key, field])
        return reply.stringValue
    }
}
