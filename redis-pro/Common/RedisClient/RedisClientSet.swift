//
//  RedisClientSet.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - Set Operations
extension RedisClient {
    
    func pageSet(_ key: String, page: Page) async throws -> ([String], Page) {
        logger.info("redis set page, key: \(key), page: \(page)")
        begin()
        defer { complete() }
        
        do {
            var page = page
            try await assertExist(key)
            let isScan = isScan(page.keywords)
            var r: [String] = []
            
            if isScan {
                let match = page.keywords.isEmpty ? nil : page.keywords
                let pageData: [String] = try await _setPageScan(key, page: page)
                r = r + pageData
                
                let total = try await _setCountScan(key, keywords: match)
                page.total = total
            } else {
                let exist = try await _sexist(key, ele: page.keywords)
                if exist {
                    r = [page.keywords]
                    page.total = 1
                }
            }
            return (r, page)
        } catch {
            handleError(error)
        }
        return ([], page)
    }
    
    private func _setCountScan(_ key: String, keywords: String?) async throws -> Int {
        if isMatchAll(keywords ?? "") {
            logger.info("keywords is match all, use scard...")
            return try await _scard(key)
        }
        
        var cursor: Int = 0
        var count: Int = 0
        
        while true {
            let res = try await _sscan(key, keywords: keywords, cursor: cursor, count: dataCountScanCount)
            logger.info("set loop scan count, current cursor: \(cursor), total count: \(count)")
            cursor = res.cursor
            count = count + res.elements.count
            
            if cursor == 0 {
                break
            }
        }
        return count
    }
    
    private func _setPageScan(_ key: String, page: Page) async throws -> [String] {
        let keywords = page.keywords.isEmpty ? nil : page.keywords
        var end: Int = page.end
        var cursor: Int = 0
        var elements: [String] = []
        
        while true {
            let res = try await _sscan(key, keywords: keywords, cursor: cursor, count: dataScanCount)
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
        return Array(elements[start..<end])
    }
    
    func _sscan(_ key: String, keywords: String?, cursor: Int, count: Int = 1) async throws -> (cursor: Int, elements: [String]) {
        logger.debug("redis set scan, key: \(key) cursor: \(cursor), keywords: \(String(describing: keywords)), count:\(String(describing: count))")
        var args = [key, String(cursor)]
        if let match = keywords, !match.isEmpty {
            args += ["MATCH", match]
        }
        args += ["COUNT", String(count)]
        
        let reply = try await execute(command: "SSCAN", args: args)
        guard let arr = reply.arrayValue, arr.count >= 2 else {
            return (0, [])
        }
        
        let newCursor = arr[0].intValue ?? 0
        let elements = arr[1].arrayValue?.compactMap { $0.stringValue } ?? []
        return (newCursor, elements)
    }
    
    private func _sexist(_ key: String, ele: String?) async throws -> Bool {
        guard let ele = ele else { return false }
        let reply = try await execute(command: "SISMEMBER", args: [key, ele])
        return reply.intValue == 1
    }
    
    func supdate(_ key: String, from: String, to: String) async throws -> Int {
        begin()
        defer { complete() }
        logger.info("redis set update, key: \(key), from: \(from), to: \(to)")
        
        do {
            let r = try await _srem(key, ele: from)
            try Assert.isTrue(r > 0, message: "set element: `\(from)` is not exist!")
            return try await _sadd(key, ele: to)
        } catch {
            handleError(error)
        }
        return 0
    }
    
    func srem(_ key: String, ele: String) async throws -> Int {
        begin()
        defer { complete() }
        return try await _srem(key, ele: ele)
    }
    
    func sadd(_ key: String, ele: String) async throws -> Int {
        begin()
        defer { complete() }
        return try await _sadd(key, ele: ele)
    }
    
    private func _scard(_ key: String) async throws -> Int {
        let reply = try await execute(command: "SCARD", args: [key])
        return reply.intValue ?? 0
    }
    
    private func _srem(_ key: String, ele: String) async throws -> Int {
        let reply = try await execute(command: "SREM", args: [key, ele])
        return reply.intValue ?? 0
    }
    
    private func _sadd(_ key: String, ele: String) async throws -> Int {
        let reply = try await execute(command: "SADD", args: [key, ele])
        return reply.intValue ?? 0
    }
}
