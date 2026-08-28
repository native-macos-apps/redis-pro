//
//  RedisClientZSet.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - Sorted Set Operations
extension RedisClient {
    
    func pageZSet(_ key: String, page: Page) async throws -> ([RedisZSetItemModel], Page) {
        logger.info("redis zset page, key: \(key), page: \(page)")
        begin()
        defer { complete() }
        
        do {
            var page = page
            try await assertExist(key)
            let isScan = isScan(page.keywords)
            var r: [(String, String)] = []
            
            if isMatchAll(page.keywords) {
                r = try await _zrange(key, page: page)
                page.total = try await _zcard(key)
            }
            else if isScan {
                let match = page.keywords.isEmpty ? nil : page.keywords
                let pageData = try await zsetPageScan(key, page: page)
                r = r + pageData
                
                let total = try await zsetCountScan(key, keywords: match)
                page.total = total
            } else {
                let score = try await _zscore(key, ele: page.keywords)
                if let score = score {
                    r = [(page.keywords, "\(score)")]
                    page.total = 1
                }
            }
            return (r.map { RedisZSetItemModel(value: $0.0, score: $0.1) }, page)
        } catch {
            handleError(error)
        }
        return ([], page)
    }
    
    private func zsetCountScan(_ key: String, keywords: String?) async throws -> Int {
        if isMatchAll(keywords ?? "") {
            logger.info("keywords is match all, use zcard...")
            return try await _zcard(key)
        }
        
        var cursor: Int = 0
        var count: Int = 0
        
        while true {
            let res = try await zscan(key, keywords: keywords, cursor: cursor, count: dataCountScanCount)
            logger.info("set loop scan count, current cursor: \(cursor), total count: \(count)")
            cursor = res.cursor
            count = count + res.elements.count
            
            if cursor == 0 {
                break
            }
        }
        return count
    }
    
    private func zsetPageScan(_ key: String, page: Page) async throws -> [(String, String)] {
        let keywords = page.keywords.isEmpty ? nil : page.keywords
        var end: Int = page.end
        var cursor: Int = 0
        var elements: [(String, Double)] = []
        
        while true {
            let res = try await zscan(key, keywords: keywords, cursor: cursor, count: dataScanCount)
            logger.info("set loop scan page, current cursor: \(cursor), total count: \(elements.count)")
            cursor = res.cursor
            elements = elements + res.elements
            
            if cursor == 0 || elements.count >= end {
                break
            }
        }
        
        let start = page.start
        if start >= elements.count {
            return []
        }
        
        end = min(end, elements.count)
        return Array(elements[start..<end]).map { ($0.0, "\($0.1)") }
    }
    
    func zscan(_ key: String, keywords: String?, cursor: Int, count: Int? = 1) async throws -> (cursor: Int, elements: [(String, Double)]) {
        logger.debug("redis zset scan, key: \(key) cursor: \(cursor), keywords: \(String(describing: keywords)), count:\(String(describing: count))")
        var args = [key, String(cursor)]
        if let match = keywords, !match.isEmpty {
            args += ["MATCH", match]
        }
        if let count = count {
            args += ["COUNT", String(count)]
        }
        
        let reply = try await execute(command: "ZSCAN", args: args)
        guard let arr = reply.arrayValue, arr.count >= 2 else {
            return (0, [])
        }
        
        let newCursor = arr[0].intValue ?? 0
        var elements: [(String, Double)] = []
        
        if let items = arr[1].arrayValue {
            var i = 0
            while i + 1 < items.count {
                if let val = items[i].stringValue, let score = items[i + 1].doubleValue {
                    elements.append((val, score))
                }
                i += 2
            }
        }
        
        return (newCursor, elements)
    }
    
    func zupdate(_ key: String, from: String, to: String, score: Double) async throws -> Bool {
        logger.info("update zset element key: \(key), from:\(from), to:\(to), score:\(score)")
        begin()
        defer { complete() }
 
        do {
            let r = try await _zrem(key, ele: from)
            try Assert.isTrue(r > 0, message: "set zset element: `\(from)` is not exist!")
            return try await _zadd(key, score: score, ele: to)
        } catch {
            handleError(error)
        }
        return false
    }
    
    func zadd(_ key: String, score: Double, ele: String) async throws -> Bool {
        begin()
        defer { complete() }
        return try await _zadd(key, score: score, ele: ele)
    }
    
    private func _zadd(_ key: String, score: Double, ele: String) async throws -> Bool {
        let reply = try await execute(command: "ZADD", args: [key, String(score), ele])
        return !reply.isError
    }
    
    private func _zcard(_ key: String) async throws -> Int {
        let reply = try await execute(command: "ZCARD", args: [key])
        return reply.intValue ?? 0
    }
    
    func zrem(_ key: String, ele: String) async throws -> Int {
        begin()
        defer { complete() }
        do {
            return try await _zrem(key, ele: ele)
        } catch {
            handleError(error)
        }
        return 0
    }
    
    private func _zrem(_ key: String, ele: String) async throws -> Int {
        let reply = try await execute(command: "ZREM", args: [key, ele])
        return reply.intValue ?? 0
    }
    
    private func _zscore(_ key: String, ele: String) async throws -> Double? {
        let reply = try await execute(command: "ZSCORE", args: [key, ele])
        return reply.doubleValue
    }
    
    private func _zrange(_ key: String, page: Page) async throws -> [(String, String)] {
        // ZRANGE key start stop WITHSCORES
        let reply = try await execute(command: "ZRANGE", args: [key, "\(page.start)", "\(page.end - 1)", "WITHSCORES"])
        var result: [(String, String)] = []
        
        if let tokens = reply.arrayValue {
            var i = 0
            while i + 1 < tokens.count {
                if let member = tokens[i].stringValue, let score = tokens[i + 1].stringValue {
                    result.append((member, score))
                }
                i += 2
            }
        }
        return result
    }
    
    func geopos(_ key: String, member: String) async throws -> [String]? {
        logger.info("redis geopos, key: \(key), member: \(member)")
        begin()
        defer { complete() }
        
        let reply = try await execute(command: "GEOPOS", args: [key, member])
        if let arr = reply.arrayValue, let first = arr.first?.arrayValue, first.count >= 2 {
            if let lon = first[0].stringValue, let lat = first[1].stringValue {
                return [lon, lat]
            }
        }
        return nil
    }
}
