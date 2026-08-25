//
//  RedisClientConfig.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - Config Operations
extension RedisClient {
    func getConfigList(_ pattern: String = "*") async throws -> [RedisConfigItemModel] {
        logger.info("get redis config list, pattern: \(pattern)...")
        
        let reply = try await execute(command: "CONFIG", args: ["GET", pattern.isEmpty ? "*" : pattern])
        var configList = [RedisConfigItemModel]()
        
        if let map = reply.mapValue {
            for (k, v) in map {
                let keyStr = k.stringValue ?? ""
                let valStr = v.stringValue ?? ""
                configList.append(RedisConfigItemModel(key: keyStr, value: valStr))
            }
        } else if let arr = reply.arrayValue {
            var i = 0
            while i + 1 < arr.count {
                let keyStr = arr[i].stringValue ?? ""
                let valStr = arr[i + 1].stringValue ?? ""
                configList.append(RedisConfigItemModel(key: keyStr, value: valStr))
                i += 2
            }
        }
        return configList
    }
    
    func configRewrite() async throws -> Bool {
        logger.info("redis config rewrite ...")
        let reply = try await execute(command: "CONFIG", args: ["REWRITE"])
        return reply.isOK
    }
    
    func getConfigOne(key: String) async throws -> String? {
        logger.info("get redis config ...")
        let reply = try await execute(command: "CONFIG", args: ["GET", key])
        if let map = reply.mapValue {
            for (k, v) in map {
                if k.stringValue == key {
                    return v.stringValue
                }
            }
        } else if let arr = reply.arrayValue, arr.count >= 2 {
            return arr[1].stringValue
        }
        return nil
    }
    
    func setConfig(key: String, value: String) async throws -> Bool {
        logger.info("set redis config, key: \(key), value: \(value)")
        let reply = try await execute(command: "CONFIG", args: ["SET", key, value])
        return reply.isOK
    }
}
