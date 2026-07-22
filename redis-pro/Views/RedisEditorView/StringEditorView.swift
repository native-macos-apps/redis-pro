//
//  StringEditView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/7.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

enum StringViewMode: String, CaseIterable {
    case plain = "Plain Text"
    case json = "JSON"
}

struct StringEditorView: View {
    @State var viewModel: ValueViewModel
    @State private var viewMode: StringViewMode = .plain
    @FocusState private var isFocused: Bool
    private let logger = Logger(label: "string-editor")

    var body: some View {
        let vm = viewModel.stringValue
        VStack(alignment: .leading, spacing: 0) {
            editorArea(vm: vm)

            // Footer
            HStack(alignment: .center, spacing: 6) {
                Button(action: { vm.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                KeyObjectBar(viewModel: viewModel.keyObject)

                Spacer()

                Picker("", selection: $viewMode) {
                    ForEach(StringViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Button(action: { vm.submit() }) {
                    Label("Submit", systemImage: "checkmark")
                }
            }
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .frame(height: 30)
        }
        .onAppear {
            logger.info("redis string value editor view appear ...")
        }
    }

    // MARK: - Editor Area

    @ViewBuilder
    private func editorArea(vm: StringValueViewModel) -> some View {
        if viewMode == .json {
            // JSON mode: show formatted + syntax-highlighted attributed string (read-only display)
            // while keeping a hidden editable TextEditor in sync for actual editing
            jsonEditorArea(vm: vm)
        } else {
            // Plain text mode: fully editable SwiftUI TextEditor
            TextEditor(text: Binding(get: { vm.text }, set: { vm.text = $0 }))
                .font(.system(.body, design: .monospaced))
                .lineSpacing(2)
                .disableAutocorrection(true)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func jsonEditorArea(vm: StringValueViewModel) -> some View {
        let formatted = formatJSON(vm.text)
        let attributed = JSONHighlighter.highlight(formatted)

        ScrollView(.vertical) {
            Text(attributed)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatJSON(_ val: String) -> String {
        guard val.count >= 2,
              let data = val.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else { return val }
        return prettyString
    }
}
