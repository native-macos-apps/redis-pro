//
//  RedisValueFooterView.swift
//  redis-pro
//
//  Unified footer for Redis key value editors.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI

struct RedisValueFooterView: View {
    @State var viewModel: ValueViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            KeyObjectBar(viewModel: viewModel.keyObject)

            Spacer()

            // Context-specific actions
            if viewModel.key.type == RedisKeyTypeEnum.STRING.rawValue {
                stringActions(vm: viewModel.stringValue)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func stringActions(vm: StringValueViewModel) -> some View {
        Picker("", selection: Binding(
            get: { vm.viewMode },
            set: { vm.viewMode = $0 }
        )) {
            ForEach(StringViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
        .controlSize(.small)

        Button(action: { vm.submit() }) {
            Label("Submit", systemImage: "checkmark")
        }
        .controlSize(.small)
    }
}
