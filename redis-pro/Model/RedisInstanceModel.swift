//
//  RedisInstanceModel.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/1/25.
//

import SwiftUI
import Foundation
import NIO
import Logging


class RedisInstanceModel: Identifiable, @unchecked Sendable {
    var redisModel:RedisModel
    private var redisClient:RedisClient?
    
    let logger = Logger(label: "redis-instance")
    
    
    init(redisModel: RedisModel) {
        self.redisModel = redisModel
        logger.info("redis instance model init")
    }
    
    convenience init(_ redisClient: RedisClient) {
        self.init(redisModel: redisClient.redisModel)
        self.redisClient = redisClient
    }
    
    // get client
    func getClient() -> RedisClient {
        if let client = redisClient {
            return client
        }
        
        return initRedisClient(self.redisModel)
    }
    
    // init redis client
    func initRedisClient(_ redisModel: RedisModel) -> RedisClient {
        
        logger.info("init new redis client, redisModel: \(redisModel)")
        self.redisModel = redisModel
        let client = RedisClient(redisModel)
        
        self.redisClient = client
        return client
    }
    
    func connect(_ redisModel:RedisModel) async -> Bool {
        logger.info("connect to redis server: \(redisModel)")
        do {
            let r = await testConnect(redisModel)
            if r {
                let _ = try await initRedisClient(redisModel).getConn()
            }
            
            return r
        } catch {
            Task { @MainActor in Messages.show(error) }
            return false
        }
    }
    
    func testConnect(_ redisModel:RedisModel) async -> Bool {
        defer {
            self.close()
        }
        logger.info("test connect to redis server: \(redisModel)")
        return (try? await initRedisClient(redisModel).testConn()) ?? false
    }
    
    func close() -> Void {
        logger.info("redis stack client close...")
        redisClient?.close()
        redisClient = nil
    }
    
    func shutdown() -> Void {
        redisClient?.shutdown()
    }
}
