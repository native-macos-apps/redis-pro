//
//  RedisClientSystem.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - System Operations
extension RedisClient {
    
    func selectDB(_ database: Int) async throws -> Bool {
        self.logger.info("select db: \(database)")
        self.redisModel.database = database
        let client = try await getClient()
        return try await client.selectDB(database)
    }
    
    func databases() async throws -> Int {
        let reply = try await execute(command: "CONFIG", args: ["GET", "databases"])
        if let arr = reply.arrayValue, arr.count >= 2 {
            return arr[1].intValue ?? 16
        } else if let map = reply.mapValue {
            for (k, v) in map {
                if k.stringValue == "databases" {
                    return v.intValue ?? 16
                }
            }
        }
        return 16 // Default
    }
    
    func dbsize() async throws -> Int {
        let reply = try await execute(command: "DBSIZE", args: [])
        return reply.intValue ?? 0
    }
    
    func flushDB() async throws -> Bool {
        let reply = try await execute(command: "FLUSHDB", args: [])
        return reply.isOK
    }
    
    func resetState() async throws -> Bool {
        logger.info("reset state...")
        self.close()
        _ = try await getClient()
        return true
    }
    
    func ping() async throws -> Bool {
        let client = try await getClient()
        return try await client.ping()
    }
}
