//
//  RedisClientSystem.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation
import Valkey

// MARK: - system function
extension RedisClient {
    
    func selectDB(_ database: Int) async throws -> Bool {
        self.logger.info("select db: \(database)")
        self.redisModel.database = database
        
        // In Valkey, it's better to re-initialize the client with the new DB
        // to ensure the connection pool is correctly pointed to the new DB.
        self.close()
        _ = try await getClient()
        return true
    }
    
    func databases() async throws -> Int {
        let res: RESPToken? = try await self.send("CONFIG", args: ["GET", "databases"])
        if let tokenMap = try? res?.decode(as: RESPToken.Map.self) {
            for entry in tokenMap {
                if String(fromValkeyValue: entry.key) == "databases" {
                    return Int(fromValkeyValue: entry.value)
                }
            }
            var iterator = tokenMap.makeIterator()
            if let first = iterator.next() {
                return Int(fromValkeyValue: first.value)
            }
        } else if let tokenArray = try? res?.decode(as: RESPToken.Array.self) {
            let arr = Swift.Array(tokenArray)
            if arr.count >= 2 {
                return Int(fromValkeyValue: arr[1])
            }
        }
        return 16 // Default
    }
    
    func dbsize() async throws -> Int {
        let res: Int? = try await self.send("DBSIZE")
        return res ?? 0
    }
    
    func flushDB() async throws -> Bool {
        let res: String? = try await self.send("FLUSHDB")
        return res == "OK"
    }
    
    func clientKill(_ clientModel: ClientModel) async throws -> Bool {
        let res: String? = try await self.send("CLIENT", args: ["KILL", clientModel.addr])
        return res == "OK"
    }
    
    func clientList() async throws -> [ClientModel] {
        let res: String? = try await self.send("CLIENT", args: ["LIST"])
        let listStr = res ?? ""
        return ClientModel.parse(listStr)
    }
    
    func info() async throws -> [RedisInfoModel] {
        let res: String? = try await self.send("INFO")
        return RedisInfoModel.parse(res ?? "")
    }
    
    func resetState() async throws -> Bool {
        logger.info("reset state...")
        // Valkey doesn't have a direct 'resetState' but we can re-init
        self.close()
        _ = try await getClient()
        return true
    }
    
    func ping() async throws -> Bool {
        let res: String? = try await self.send("PING")
        return res == "PONG"
    }
}
