//
//  RedisClientSlowLog.swift
//  redis-pro
//
//  Created by chengpan on 2022/3/6.
//

import Foundation

// MARK: - Slow Log Operations
extension RedisClient {
    func slowLogReset() async throws -> Bool {
        logger.info("slow log reset ...")
        let reply = try await execute(command: "SLOWLOG", args: ["RESET"])
        return reply.isOK
    }
    
    func slowLogLen() async throws -> Int {
        logger.info("get slow log len ...")
        let reply = try await execute(command: "SLOWLOG", args: ["LEN"])
        return reply.intValue ?? 0
    }
    
    func getSlowLog(_ size: Int) async throws -> [SlowLogModel] {
        logger.info("get slow log list ...")
        
        let reply = try await execute(command: "SLOWLOG", args: ["GET", String(size)])
        guard let items = reply.arrayValue else { return [] }
        
        var slowLogs = [SlowLogModel]()
        for item in items {
            guard let itemArray = item.arrayValue, itemArray.count >= 4 else { continue }
            
            let id = itemArray[0].stringValue ?? ""
            let timestamp = itemArray[1].intValue ?? 0
            let execTime = itemArray[2].stringValue ?? "0"
            
            var cmd = ""
            if let cmdTokens = itemArray[3].arrayValue {
                cmd = cmdTokens.compactMap { $0.stringValue }.joined(separator: " ")
            }
            
            let clientAddr = itemArray.count > 4 ? itemArray[4].stringValue : nil
            let clientName = itemArray.count > 5 ? itemArray[5].stringValue : nil
            
            slowLogs.append(SlowLogModel(id: id, timestamp: timestamp, execTime: execTime, cmd: cmd, client: clientAddr, clientName: clientName))
        }
        return slowLogs
    }
}
