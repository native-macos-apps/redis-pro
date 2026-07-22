//
//  RedisConfigView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/7/21.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct RedisConfigView: View {

    @State var viewModel: RedisConfigViewModel
    let logger = Logger(label: "redis-config-view")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                SearchBar(placeholder: "Search config...", onCommit: { viewModel.search($0) })
                Spacer()
                Button("Rewrite") { viewModel.rewrite() }
                    .help("REDIS_CONFIG_REWRITE")
            }.padding(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            NTableView(viewModel: viewModel.table) { index in
                Button {
                    viewModel.edit(index)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .keyboardShortcut("e")
            }

            HStack(alignment: .center, spacing: 6) {
                Spacer()
                Button("Refresh") { viewModel.refresh() }
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.editModalVisible }, set: { viewModel.editModalVisible = $0 })) {
            ModalView("Edit Config Key: \(viewModel.editKey)", action: { viewModel.submit() }) {
                MTextEditor(text: Binding(get: { viewModel.editValue }, set: { viewModel.editValue = $0 }))
                    .frame(minWidth: 500, minHeight: 300)
            }
        }
        .onAppear {
            viewModel.initial()
        }
    }
}
