//
//  MPasswordField.swift
//  redis-pro
//
//  Created by chengpan on 2021/12/12.
//  Migrated to LiquidGlass (Swift 6)
//

import SwiftUI
import Logging

struct MPasswordField: View {
    @Binding var value: String
    var placeholder: String = "Password"
    var onCommit: (() -> Void)?

    @State private var visible: Bool = false
    @FocusState private var isFocused: Bool

    let logger = Logger(label: "pass-field")

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Group {
                if visible {
                    TextField("", text: $value, prompt: Text(placeholder))
                        .onSubmit { onCommit?() }
                } else {
                    SecureField("", text: $value, prompt: Text(placeholder))
                        .onSubmit { onCommit?() }
                        .textContentType(.password)
                }
            }
            .labelsHidden()
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .font(.body)
            .disableAutocorrection(true)
            .textFieldStyle(.plain)
            .focused($isFocused)

            Button(action: { visible.toggle() }) {
                Image(systemName: visible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(isFocused ? .accentColor.opacity(0.15) : .clear).interactive(), in: .rect(cornerRadius: 6))
    }
}
