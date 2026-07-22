//
//  RedisInfoView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/6/10.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct RedisInfoView: View {
    @State var viewModel: RedisInfoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TabView(selection: Binding(
                get: { viewModel.section },
                set: { viewModel.setTab($0) }
            )) {
                ForEach(viewModel.redisInfoModels.indices, id: \.self) { index in
                    NTableView(viewModel: viewModel.table)
                        .tabItem {
                            Text(viewModel.redisInfoModels[index].section)
                        }
                        .tag(viewModel.redisInfoModels[index].section)
                }
            }
            .frame(minWidth: 500, minHeight: 600)

            HStack(alignment: .center, spacing: 8) {
                Spacer()
                Button("Reset State") { viewModel.resetState() }
                Button("Refresh") { viewModel.refresh() }
            }
        }
        .onAppear {
            viewModel.initial()
        }
    }
}
