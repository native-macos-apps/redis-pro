//
//  MIntField.swift
//  redis-pro
//
//  Created by chengpan on 2021/12/11.
//  Migrated to LiquidGlass (Swift 6)
//

import SwiftUI
import Logging

struct MIntField: View {
    @Binding var value: Int
    var placeholder: String?
    var onCommit: (() -> Void)?

    @FocusState private var isFocused: Bool

    let logger = Logger(label: "int-field")

    var body: some View {
        TextField("", value: $value, formatter: NumberHelper.intFormatter,
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

    func doCommit() {
        logger.info("on textField commit, value: \(value)")
        onCommit?()
    }
}
