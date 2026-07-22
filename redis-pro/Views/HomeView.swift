//
//  HomeView.swift
//  redis-pro
//
//  Created by chengpan on 2021/4/4.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct HomeView: View {
    private static let logger = Logger(label: "home-view")
    @State var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RedisKeysListView(viewModel: viewModel.redisKeys)
            .onAppear {
                Self.logger.info("redis pro home view init complete")
                viewModel.initial()
            }
            .onDisappear {
                Self.logger.info("redis pro home view destroy...")
                viewModel.onClose()
            }
            .onChange(of: viewModel.isConnect) { oldValue, newValue in
                if !newValue {
                    // Disconnected: Open Login window and close this Workspace window
                    openWindow(id: "login-window")
                    dismiss()
                }
            }
            // 设置window标题
            .navigationTitle(viewModel.title)
            .textFieldStyle(.roundedBorder)
            .buttonStyle(.bordered)
    }
}
