//
//  StringEditView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/7.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct StringEditorView: View {
    @State var viewModel: ValueViewModel
    @FocusState private var isFocused: Bool
    private let logger = Logger(label: "string-editor")

    var body: some View {
        let vm = viewModel.stringValue
        VStack(alignment: .leading, spacing: 0) {
            editorArea(vm: vm)
        }
        .onAppear {
            logger.info("redis string value editor view appear ...")
        }
    }

    // MARK: - Editor Area

    @ViewBuilder
    private func editorArea(vm: StringValueViewModel) -> some View {
        if vm.viewMode == .json {
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
