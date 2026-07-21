//
//  LoginView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/1/25.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import AppKit
import Logging

struct LoginView: View {
    private static let logger = Logger(label: "login-view")

    @State var viewModel: AppViewModel
    @State private var showEditSheet = false

    private var favoriteViewModel: FavoriteViewModel {
        viewModel.favorite
    }

    init(viewModel: AppViewModel) {
        Self.logger.info("login view init...")
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationSplitView {
            sidebarPanel
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Divider()
            connectionListPanel
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    favoriteViewModel.login.redisModel = RedisModel()
                    showEditSheet = true
                }) {
                    Image(systemName: "plus").font(.system(.body))
                }
                .help("New Server")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .navigationTitle("")
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        LoginForm(viewModel: favoriteViewModel.login)
    }

    // MARK: - Left Sidebar

    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            brandingSection
                .padding(.top, 60)

            Spacer()

            creditSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { onLoad() }
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: 12) {
            // Redis-style icon: red rounded rect with database symbol
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.22, blue: 0.18),
                                Color(red: 0.63, green: 0.10, blue: 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .shadow(
                        color: Color(red: 0.88, green: 0.22, blue: 0.18).opacity(0.40),
                        radius: 12, x: 0, y: 5
                    )

                Image(systemName: "cylinder.split.1x2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Redis Pro")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Text(connectionsCountText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
                .padding(.horizontal, 24)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Credit

    private var creditSection: some View {
        Text("Credit by dungmv")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .opacity(0.7)
            .padding(.bottom, 20)
    }

    private var connectionsCountText: String {
        let count = favoriteViewModel.table.datasource.count
        return count == 1 ? "1 connection" : "\(count) connections"
    }

    // MARK: - Connection List Panel

    private var connectionListPanel: some View {
        VStack() {
            if favoriteViewModel.table.datasource.isEmpty {
                emptyState
            } else {
                connectionList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var connectionList: some View {
        let datasource = favoriteViewModel.table.datasource
        let selectedIndex = favoriteViewModel.table.selectIndex

        return List(datasource.indices, id: \.self, selection: Binding<Int?>(
            get: { selectedIndex >= 0 ? selectedIndex : nil },
            set: { newIndex in
                let idx = newIndex ?? -1
                favoriteViewModel.table.selectionChange(index: idx, indexes: idx >= 0 ? [idx] : [])
            }
        )) { index in
            ConnectionRow(model: datasource[index])
                .tag(index)
                .listRowSeparator(.hidden)
                .contextMenu {
                    Button("Connect") { favoriteViewModel.connect(index) }
                    Button("Edit") {
                        favoriteViewModel.table.selectionChange(index: index, indexes: [index])
                        showEditSheet = true
                    }
                    Divider()
                    Button("Duplicate") {
                        let model = datasource[index]
                        var copy = model
                        copy.id = UUID().uuidString
                        copy.name = (model.name.isEmpty ? "New Connection" : model.name) + " Copy"
                        favoriteViewModel.save(copy)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        favoriteViewModel.deleteConfirm(index)
                    }
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No connections")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Click \"+\" in the toolbar to add your first Redis connection.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Window Setup

    private func onLoad() {
        favoriteViewModel.getAll()
        favoriteViewModel.initDefaultSelection()
        let idx = favoriteViewModel.table.defaultSelectIndex
        if idx >= 0, idx < favoriteViewModel.table.datasource.count {
            favoriteViewModel.table.selectionChange(index: idx, indexes: [idx])
        }
    }
}

// MARK: - Connection Row

private struct ConnectionRow: View {
    let model: RedisModel

    var body: some View {
        HStack(spacing: 16) {
            typeIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(model.name.isEmpty ? "New Connection" : model.name)
                    .font(.system(.body))

                Text("redis://\(model.host):\(model.port)")
                    .font(.system(.caption))
            }
        }
    }

    @ViewBuilder
    private var typeIcon: some View {
        Image(systemName: "cylinder.split.1x2")
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
    }
}
