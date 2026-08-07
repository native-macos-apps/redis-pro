//
//  RedisKeysTreeView.swift
//  redis-pro
//
//  Sidebar tree — delegates to RedisKeysOutlineView (native NSOutlineView).
//  Migrated to MVVM (Swift 6)
//

import SwiftUI

// MARK: - Root tree view

struct RedisKeysTreeView: View {
    @State var viewModel: RedisKeysViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            RedisKeysOutlineView(viewModel: viewModel)
        }
    }

    private var headerView: some View {
        HStack {
            Text("KEYS").font(.system(.caption))
            Spacer()
            Text("\(viewModel.dbsize)").font(.system(.caption))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
