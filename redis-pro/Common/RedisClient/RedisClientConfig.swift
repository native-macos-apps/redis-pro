//
//  RedisClientConfig.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation
import Valkey

// MARK: - config
extension RedisClient {
    func getConfigList(_ pattern: String = "*") async throws -> [RedisConfigItemModel] {
        logger.info("get redis config list, pattern: \(pattern)...")
        
        let res: RESPToken? = try await self.send("CONFIG", args: ["GET", pattern.isEmpty ? "*" : pattern])
        var configList = [RedisConfigItemModel]()
        
        if let tokenMap = try? res?.decode(as: RESPToken.Map.self) {
            for entry in tokenMap {
                let k = String(fromValkeyValue: entry.key)
                let v = String(fromValkeyValue: entry.value)
                configList.append(RedisConfigItemModel(key: k, value: v))
            }
        } else if let tokenArray = try? res?.decode(as: RESPToken.Array.self) {
            let arr = Swift.Array(tokenArray)
            let max: Int = arr.count / 2
            for index in (0..<max) {
                configList.append(RedisConfigItemModel(key: String(fromValkeyValue: arr[index * 2]), value: String(fromValkeyValue: arr[index * 2 + 1])))
            }
        }
        return configList
    }
    
    func configRewrite() async throws -> Bool {
        logger.info("redis config rewrite ...")
        let res: RESPToken? = try await self.send("CONFIG", args: ["REWRITE"])
        return (try? res?.decode(as: String.self)) == "OK"
    }
    
    func getConfigOne(key: String) async throws -> String? {
        logger.info("get redis config ...")
        let res: RESPToken? = try await self.send("CONFIG", args: ["GET", key])
        if let tokenMap = try? res?.decode(as: RESPToken.Map.self) {
            for entry in tokenMap {
                if String(fromValkeyValue: entry.key) == key {
                    return String(fromValkeyValue: entry.value)
                }
            }
            var iterator = tokenMap.makeIterator()
            if let first = iterator.next() {
                return String(fromValkeyValue: first.value)
            }
        } else if let tokenArray = try? res?.decode(as: RESPToken.Array.self) {
            let arr = Swift.Array(tokenArray)
            if arr.count >= 2 {
                return String(fromValkeyValue: arr[1])
            }
        }
        return nil
    }
    
    func setConfig(key: String, value: String) async throws -> Bool {
        logger.info("set redis config, key: \(key), value: \(value)")
        let res: RESPToken? = try await self.send("CONFIG", args: ["SET", key, value])
        return (try? res?.decode(as: String.self)) == "OK"
    }
}
