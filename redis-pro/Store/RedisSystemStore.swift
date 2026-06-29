//
//  RedisSystemStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/6/4.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

enum RedisSystemViewTypeEnum {
    case REDIS_INFO
    case REDIS_CONFIG
    case CLIENT_LIST
    case SLOW_LOG
    case LUA
}

private let logger = Logger(label: "redis-system-store")

@MainActor
@Observable
final class RedisSystemViewModel {
    var systemView: RedisSystemViewTypeEnum = .REDIS_INFO

    let redisInfo: RedisInfoViewModel
    let redisConfig: RedisConfigViewModel
    let slowLog: SlowLogViewModel
    let clientList: ClientListViewModel
    let lua: LuaViewModel

    // Callback when system view panel is opened
    var onSetSystemView: (() -> Void)?

    init(redisInstance: RedisInstanceModel) {
        self.redisInfo = RedisInfoViewModel(redisInstance: redisInstance)
        self.redisConfig = RedisConfigViewModel(redisInstance: redisInstance)
        self.slowLog = SlowLogViewModel(redisInstance: redisInstance)
        self.clientList = ClientListViewModel(redisInstance: redisInstance)
        self.lua = LuaViewModel(redisInstance: redisInstance)
        logger.info("RedisSystemViewModel init ...")
    }

    func setSystemView(_ type: RedisSystemViewTypeEnum) {
        systemView = type
        onSetSystemView?()
    }
}
