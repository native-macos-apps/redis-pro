//
//  SearchBar.swift
//  redis-pro
//
//  Liquid Glass search field with history dropdown.
//

import SwiftUI
import Logging

struct SearchBar: View {

    @State private var keywords: String = ""
    @FocusState private var isFocused: Bool

    var placeholder: String = "Search..."
    var onCommit: ((String) -> Void)?
    var onChange: ((String) -> Void)?

    private static let logger = Logger(label: "search-bar")

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("", text: $keywords, prompt: Text(placeholder).foregroundColor(.secondary))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFocused)
                    .onSubmit { commit() }

                if !keywords.isEmpty {
                    Button(action: {
                        keywords = ""
                        onCommit?("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        }
    }

    // MARK: - Private

    private func commit() {
        Self.logger.info("SearchBar commit, keywords: \(keywords)")
        onCommit?(keywords)
    }
}
