//
//  SlowLogView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/7/14.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct SlowLogView: View {
    @State var viewModel: SlowLogViewModel
    let logger = Logger(label: "slow-log-view")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // header
            HStack(alignment: .center, spacing: 8) {
                FormItemInt(
                    label: "Slower Than(us)", labelWidth: 120,
                    value: Binding(get: { viewModel.slowerThan }, set: { viewModel.slowerThan = $0 }),
                    suffix: "square.and.pencil",
                    onCommit: { viewModel.setSlowerThan() }
                )
                .help("REDIS_SLOW_LOG_SLOWER_THAN")
                .frame(width: 320)
                FormItemInt(
                    label: "Max Len",
                    value: Binding(get: { viewModel.maxLen }, set: { viewModel.maxLen = $0 }),
                    suffix: "square.and.pencil",
                    onCommit: { viewModel.setMaxLen() }
                )
                .help("REDIS_SLOW_LOG_MAX_LEN")
                .frame(width: 200)

                FormItemInt(
                    label: "Size",
                    value: Binding(get: { viewModel.size }, set: { viewModel.size = $0 }),
                    suffix: "square.and.pencil",
                    onCommit: { viewModel.setSize() }
                )
                .help("REDIS_SLOW_LOG_SIZE")
                .frame(width: 200)

                Spacer()
                Button("Reset") { viewModel.reset() }
                    .buttonStyle(.bordered)
                    .help("REDIS_SLOW_LOG_RESET")
            }

            NTableView(viewModel: viewModel.table)

            // footer
            HStack(alignment: .center, spacing: 12) {
                Spacer()
                Text("Total: \(viewModel.total)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .help("REDIS_SLOW_LOG_TOTAL")
                Text("Current: \(viewModel.table.datasource.count)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .help("REDIS_SLOW_LOG_SIZE")
                Button(action: { viewModel.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
        .onAppear {
            viewModel.initial()
        }
    }
}
