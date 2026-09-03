//
//  RedisKeysListView.swift
//  redis-pro
//
//  Liquid Glass main split view (sidebar + content).
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct RedisKeysListView: View {

    @State var viewModel: RedisKeysViewModel

    private static let logger = Logger(label: "redis-key-list-view")

    var body: some View {
        NavigationSplitView {
            sidebarPanel
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 440)
        } detail: {
            contentPanel
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                DatabasePicker(viewModel: viewModel.database_)
            }
            ToolbarItem(placement: .principal) {
                connectionInfoBadge
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if viewModel.mainViewType == .ANALYSIS {
                        viewModel.setMainViewType(.EDITOR)
                    } else {
                        viewModel.selectAnalysis()
                    }
                }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewModel.mainViewType == .ANALYSIS ? Color.accentColor : Color.primary)
                }
                .help("Memory Analysis")
            }
        }
        .sheet(isPresented: addKeySheetBinding) {
            AddKeySheet(viewModel: viewModel.addKey)
        }

    }

    // MARK: - Add Key Sheet Binding

    private var addKeySheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.addKey.isVisible },
            set: { viewModel.addKey.isVisible = $0 }
        )
    }

    // MARK: - Sidebar

    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            commandQueryButton
            Divider()
            RedisKeysTreeView(viewModel: viewModel)
            Divider()
            sidebarFooter
        }
    }

    private var commandQueryButton: some View {
        Button(action: {
            viewModel.selectCommandQuery()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .medium))
                Text("Command Query")
                    .font(.system(.body, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.mainViewType == .QUERY ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(viewModel.mainViewType == .QUERY ? .white : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var sidebarHeader: some View {
        SearchBar(
            placeholder: "Search keys...",
            onCommit: { viewModel.search($0) },
            onChange: { viewModel.searchChange($0) }
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var sidebarFooter: some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Refresh keys")
            .padding(.leading, 10)

            Button {
                viewModel.addNew()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    // MARK: - Content

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewModel.mainViewType {
            case .EDITOR:
                RedisValueView(viewModel: viewModel.value)
            case .QUERY:
                CommandQueryView(viewModel: viewModel.commandQuery)
            case .ANALYSIS:
                RedisAnalysisView(viewModel: viewModel.analysis)
            case .NONE:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Connection Info Badge

    private var connectionIcon: String {
        switch viewModel.redisModel.connectionType.lowercased() {
        case "ssh": return "lock.fill"
        case "sentinel": return "shield.lefthalf.filled"
        case "cluster": return "circle.hexagongrid.fill"
        default: return "network"
        }
    }

    private var connectionAddressText: String {
        switch viewModel.redisModel.connectionType.lowercased() {
        case "sentinel":
            return "Sentinel: \(viewModel.redisModel.sentinelMasterName)"
        case "cluster":
            return "Cluster: \(viewModel.redisModel.clusterNodes)"
        default:
            return "\(viewModel.redisModel.host):\(String(viewModel.redisModel.port))"
        }
    }

    private var connectionInfoBadge: some View {
        HStack() {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: Color.green.opacity(0.6), radius: 2)
            
            Image(systemName: connectionIcon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Text(viewModel.redisModel.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("•")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                
                Text(connectionAddressText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }.padding(.horizontal)
    }
}
