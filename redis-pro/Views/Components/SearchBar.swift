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
    @State private var searchHistory: [String] = []
    @FocusState private var isFocused: Bool
    @State private var showHistory: Bool = false

    var placeholder: String = "Search..."
    var onCommit: ((String) -> Void)?
    var onChange: ((String) -> Void)?

    private static let logger = Logger(label: "search-bar")

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("", text: $keywords, prompt: Text(placeholder).foregroundColor(.secondary))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFocused)
                    .onSubmit { commit() }
                    .onChange(of: keywords) { _, newValue in
                        showHistory = isFocused && !searchHistory.isEmpty
                        onChange?(newValue)
                    }
                    .onChange(of: isFocused) { _, focused in
                        showHistory = focused && !searchHistory.isEmpty
                    }
                    .onHover { inside in
                        if inside { NSCursor.iBeam.push() } else { NSCursor.pop() }
                    }

                if !keywords.isEmpty {
                    Button(action: {
                        keywords = ""
                        showHistory = false
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
            .glassEffect(.regular.tint(isFocused ? .accentColor.opacity(0.15) : .clear).interactive(), in: .rect(cornerRadius: 6))
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        }
        .zIndex(10)
        .onAppear {
            searchHistory = RedisDefaults.getSearchHistory()
        }
    }

    // MARK: - History dropdown (rendered by parent overlay)

    @ViewBuilder
    var historyDropdown: some View {
        if showHistory {
            let filtered = searchHistory.filter { keywords.isEmpty || $0.localizedCaseInsensitiveContains(keywords) }
            if !filtered.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered.prefix(8), id: \.self) { item in
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(item)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            keywords = item
                            showHistory = false
                            commit()
                        }
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        Divider().padding(.horizontal, 8)
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 6))
                .zIndex(100)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }

    // MARK: - Private

    private func commit() {
        Self.logger.info("SearchBar commit, keywords: \(keywords)")
        var history = searchHistory
        history.removeAll { $0 == keywords }
        if !keywords.isEmpty { history.insert(keywords, at: 0) }
        searchHistory = Array(history.prefix(20))
        RedisDefaults.saveSearchHistory(history: searchHistory)
        onCommit?(keywords)
        showHistory = false
    }
}
