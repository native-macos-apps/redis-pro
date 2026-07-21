//
//  RedisSystemView.swift
//  redis-pro
//
//  Created by chengpan on 2022/6/4.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct RedisSystemView: View {
    var viewModel: RedisSystemViewModel

    var body: some View {
        switch viewModel.systemView {
        case .REDIS_INFO:
            RedisInfoView(viewModel: viewModel.redisInfo)
        case .CLIENT_LIST:
            ClientsListView(viewModel: viewModel.clientList)
        case .SLOW_LOG:
            SlowLogView(viewModel: viewModel.slowLog)
        case .REDIS_CONFIG:
            RedisConfigView(viewModel: viewModel.redisConfig)
        case .LUA:
            LuaView(viewModel: viewModel.lua)
        }
    }
}
