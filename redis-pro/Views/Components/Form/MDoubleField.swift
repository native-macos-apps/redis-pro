//
//  MDoubleField.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/5/7.
//  Migrated to LiquidGlass (Swift 6)
//

import SwiftUI
import Logging

struct MDoubleField: View {
    @Binding var value: Double
    var placeholder: String?
    var onCommit: (() -> Void)?

    @FocusState private var isFocused: Bool

    let logger = Logger(label: "double-field")

    var body: some View {
        TextField("", value: $value, formatter: NumberHelper.doubleFormatter,
                  prompt: Text(placeholder ?? ""))
            .onSubmit { onCommit?() }
            .labelsHidden()
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .font(.body)
            .disableAutocorrection(true)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(isFocused ? .accentColor.opacity(0.15) : .clear).interactive(), in: .rect(cornerRadius: 6))
            .focused($isFocused)
    }
}
