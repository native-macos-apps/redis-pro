//
//  RedisClientKeys.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation
import Logging

// MARK: - Key Operations
extension RedisClient {
    
    private func keyScan(cursor: Int, keywords: String?, count: Int? = 1) async throws -> (cursor: Int, keys: [String]) {
        logger.debug("redis keys scan, cursor: \(cursor), keywords: \(String(describing: keywords)), count:\(String(describing: count))")
        
        var args = [String(cursor)]
        if let match = keywords, !match.isEmpty {
            args += ["MATCH", match]
        }
        if let count = count {
            args += ["COUNT", String(count)]
        }
        
        let reply = try await execute(command: "SCAN", args: args)
        guard let arr = reply.arrayValue, arr.count >= 2 else {
            return (0, [])
        }
        
        let newCursor = arr[0].intValue ?? 0
        let keys = arr[1].arrayValue?.compactMap { $0.stringValue } ?? []
        return (newCursor, keys)
    }
    
    private func countScan(cursor: Int, keywords: String?, count: Int? = 1) async throws -> (cursor: Int, count: Int) {
        logger.debug("redis keys scan, cursor: \(cursor), keywords: \(String(describing: keywords)), count:\(String(describing: count))")
        
        let res = try await keyScan(cursor: cursor, keywords: keywords, count: count)
        return (res.cursor, res.keys.count)
    }
    
    private func keysCountScan(_ keywords: String?) async throws -> Int {
        if isMatchAll(keywords ?? "") {
            logger.info("keywords is match all, use dbsize...")
            return try await dbsize()
        }
        
        var cursor: Int = 0
        var count: Int = 0
        
        while true {
            let res = try await countScan(cursor: cursor, keywords: keywords, count: dataCountScanCount)
            logger.info("loop scan page, current cursor: \(cursor), total count: \(count)")
            cursor = res.cursor
            count = count + res.count
            
            if cursor == 0 {
                break
            }
        }
        return count
    }
    
    /// Scan page of keys
    private func keysPageScan(_ page: Page) async throws -> [String] {
        let keywords = page.keywords.isEmpty ? nil : page.keywords
        var end: Int = page.end
        var cursor: Int = 0
        var keys: [String] = []
        
        while true {
            let res = try await keyScan(cursor: cursor, keywords: keywords, count: dataScanCount)
            logger.info("loop scan page, current cursor: \(cursor), total count: \(keys.count)")
            cursor = res.cursor
            keys = keys + res.keys
            
            if cursor == 0 || keys.count >= end {
                break
            }
        }
        
        let start = page.start
        if start >= keys.count {
            return []
        }
        
        end = min(end, keys.count)
        return Array(keys[start..<end])
    }

    func loadKeys(cursor: Int, keywords: String, count: Int) async throws -> (cursor: Int, keys: [RedisKeyModel]) {
        begin()

        let stopwatch = Stopwatch.createStarted()
        logger.info("redis keys load more, cursor: \(cursor), count: \(count), keywords: \(keywords)")

        defer {
            self.logger.info("keys load more complete, spend: \(stopwatch.elapsedMillis()) ms")
            complete()
        }

        if isScan(keywords) {
            let match = keywords.isEmpty ? nil : keywords
            let result = try await keyScan(cursor: cursor, keywords: match, count: count)
            let models = try await self.toRedisKeyModels(result.keys)
            return (result.cursor, models)
        }

        guard cursor == 0 else {
            return (0, [])
        }

        let exist = try await self.exist(keywords)
        guard exist else {
            return (0, [])
        }

        return (0, try await self.toRedisKeyModels([keywords]))
    }

    func pageKeys(_ page: Page) async throws -> [RedisKeyModel] {
        begin()
        
        let stopwatch = Stopwatch.createStarted()
        logger.info("redis keys page scan, page: \(page)")
        
        let isScan = isScan(page.keywords)
        
        defer {
            self.logger.info("keys scan complete, spend: \(stopwatch.elapsedMillis()) ms")
            complete()
        }
        
        if isScan {
            let pageData: [String] = try await keysPageScan(page)
            return try await self.toRedisKeyModels(pageData)
        } else {
            let exist = try await self.exist(page.keywords)
            if exist {
                return try await self.toRedisKeyModels([page.keywords])
            } else {
                return []
            }
        }
    }
    
    func countKey(_ page: Page, cursor: Int) async throws -> (Int, Int) {
        let keywords = page.keywords
        if isMatchAll(keywords) {
            return (0, try await dbsize())
        }
        
        let isScan = isScan(keywords)
        let match = keywords.isEmpty ? nil : keywords
        
        if isScan {
            let res = try await countScan(cursor: cursor, keywords: match, count: dataCountScanCount)
            logger.info("count scan keys, current cursor: \(cursor), r: \(res)")
            return res
        } else {
            let count = try await self.exist(keywords) ? 1 : 0
            return (0, count)
        }
    }
    
    func toRedisKeyModels(_ keys: [String]) async throws -> [RedisKeyModel] {
        if keys.isEmpty {
            return []
        }
        
        var redisKeyModels = [RedisKeyModel]()
        let typeDict = try await getTypes(keys)
        
        for key in keys {
            redisKeyModels.append(RedisKeyModel(key, type: typeDict[key] ?? RedisKeyTypeEnum.NONE.rawValue))
        }
        
        return redisKeyModels
    }

    func getValue(_ key: String, type: String) async throws -> String {
        logger.info("get value, key: \(key), type: \(type)")
        
        switch type {
        case RedisKeyTypeEnum.STRING.rawValue:
            return try await get(key)
        case RedisKeyTypeEnum.HASH.rawValue:
            var cursor = 0
            var allEntries: [String: String] = [:]
            repeat {
                let res = try await hscan(key: key, cursor: cursor, pattern: nil, count: 2000)
                cursor = res.0
                for (f, v) in res.1 {
                    allEntries[f] = v
                }
            } while cursor != 0
            let jsonData = try JSONSerialization.data(withJSONObject: allEntries, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? ""
            
        case RedisKeyTypeEnum.LIST.rawValue:
            let elements = try await _lrange(key, start: 0, stop: -1)
            let jsonData = try JSONSerialization.data(withJSONObject: elements.compactMap { $0 }, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? ""
            
        case RedisKeyTypeEnum.SET.rawValue:
            var cursor = 0
            var allElements: [String] = []
            repeat {
                let res = try await _sscan(key, keywords: nil, cursor: cursor, count: 2000)
                cursor = res.cursor
                allElements.append(contentsOf: res.elements)
            } while cursor != 0
            let jsonData = try JSONSerialization.data(withJSONObject: allElements, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? ""
            
        case RedisKeyTypeEnum.ZSET.rawValue:
            var cursor = 0
            var allElements: [[String: Any]] = []
            repeat {
                let res = try await zscan(key, keywords: nil, cursor: cursor, count: 2000)
                cursor = res.cursor
                for (v, s) in res.elements {
                    allElements.append(["value": v, "score": s])
                }
            } while cursor != 0
            let jsonData = try JSONSerialization.data(withJSONObject: allElements, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? ""
            
        default:
            return ""
        }
    }

    func memoryUsage(_ key: String) async throws -> Int {
        let reply = try await execute(command: "MEMORY", args: ["USAGE", key])
        return reply.intValue ?? 0
    }
}
