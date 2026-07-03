//
//  ModalView.swift
//  redis-pro
//
//  Liquid Glass modal dialog.
//

import SwiftUI

struct ModalView<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    var title: String
    var action: () throws -> Void
    var content: Content
    var width: CGFloat = 640
    var height: CGFloat = 400

    init(_ title: String, action: @escaping () throws -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.content = content()
    }

    init(_ title: String, width: CGFloat, height: CGFloat, action: @escaping () throws -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.width = width
        self.height = height
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // ── Content ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)

            Divider()

            // ── Footer ──────────────────────────────────────────────────────
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Submit", action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .frame(minWidth: width, minHeight: height)
        .background(.ultraThinMaterial)
    }

    private func submit() {
        dismiss()
        try? action()
    }

    private func cancel() {
        dismiss()
    }
}
