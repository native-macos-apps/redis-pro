//
//  RedisMonitorView.swift
//  redis-pro
//
//  Created for Real-time Command Log Stream and Multi-condition Filtering.
//

import SwiftUI
import AppKit

struct RedisMonitorView: View {
    @Bindable var viewModel: RedisMonitorViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            filterBar
            Divider()
            liveCommandTable

            if let selected = viewModel.selectedEntry {
                Divider()
                detailInspector(selected)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Monitor")
                    .font(.system(size: 13, weight: .bold))

                // Streaming status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(viewModel.isMonitoring ? "Streaming" : "Stopped")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())

                // Entry count
                Text("\(viewModel.entries.count) logs")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Auto-scroll toggle
            Button(action: {
                viewModel.isAutoScrollEnabled.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isAutoScrollEnabled ? "arrow.down.to.line.compact" : "pause.circle")
                        .font(.system(size: 10, weight: .medium))
                    Text("Auto-scroll")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(viewModel.isAutoScrollEnabled ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(viewModel.isAutoScrollEnabled ? Color.accentColor.opacity(0.4) : Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Keep latest logs in view")

            // Stop / Resume Button
            Button(action: {
                viewModel.toggleMonitoring()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isMonitoring ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text(viewModel.isMonitoring ? "Stop" : "Resume")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(viewModel.isMonitoring ? Color.red : Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Clear Button
            Button(action: {
                viewModel.clear()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Clear all captured logs")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Multi-Condition Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            // DB Filter: 0 to 15 and All (no prefix)
            HStack(spacing: 4) {
                Text("DB:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.filterDb) {
                    ForEach(viewModel.availableDbs, id: \.self) { db in
                        Text(db).tag(db)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 65)
            }

            Divider().frame(height: 18)

            // Command (CMD) Input Filter
            HStack(spacing: 5) {
                Text("CMD:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("e.g. GET", text: $viewModel.filterCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 80)

                if !viewModel.filterCommand.isEmpty {
                    Button(action: { viewModel.filterCommand = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            Divider().frame(height: 18)

            // Client Filter
            HStack(spacing: 5) {
                Text("Client:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("IP / port", text: $viewModel.filterClient)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 90)

                if !viewModel.filterClient.isEmpty {
                    Button(action: { viewModel.filterClient = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            Divider().frame(height: 18)

            // Keyword / Arguments Filter
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("Filter args / key...", text: $viewModel.filterKeyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(minWidth: 120, maxWidth: 220)

                if !viewModel.filterKeyword.isEmpty {
                    Button(action: { viewModel.filterKeyword = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            // Reset filters button
            if viewModel.hasActiveFilters {
                Button(action: {
                    viewModel.resetFilters()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Reset")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Clear all active filters")
            }

            Spacer()

            // Filtered counter badge
            let matchCount = viewModel.filteredEntries.count
            Text("\(matchCount) matched")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(viewModel.hasActiveFilters ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Live Command Table

    private var liveCommandTable: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 8) {
                Text("Timestamp")
                    .frame(width: 105, alignment: .leading)
                Text("Node")
                    .frame(width: 125, alignment: .leading)
                Text("DB")
                    .frame(width: 35, alignment: .center)
                Text("Client")
                    .frame(width: 135, alignment: .leading)
                Text("Command")
                    .frame(width: 90, alignment: .leading)
                Text("Arguments")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            let items = viewModel.filteredEntries
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    if viewModel.isMonitoring {
                        ProgressView().controlSize(.small)
                        if viewModel.hasActiveFilters {
                            Text("No commands match current filter conditions")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Waiting for commands from Redis server...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Monitor is stopped")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { entry in
                                let isSelected = viewModel.selectedEntry?.id == entry.id
                                HStack(spacing: 8) {
                                    Text(entry.timestampString)
                                        .frame(width: 105, alignment: .leading)
                                        .foregroundStyle(.secondary)

                                    Text(entry.node)
                                        .frame(width: 125, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(String(entry.db))
                                        .frame(width: 35, alignment: .center)
                                        .foregroundStyle(.secondary)

                                    Text(entry.client)
                                        .frame(width: 135, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(entry.command)
                                        .frame(width: 90, alignment: .leading)
                                        .fontWeight(.bold)
                                        .foregroundStyle(commandColor(entry.command))

                                    Text(entry.arguments)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected
                                        ? Color.accentColor.opacity(0.18)
                                        : Color.primary.opacity(0.02)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.selectedEntry?.id == entry.id {
                                        viewModel.selectedEntry = nil
                                    } else {
                                        viewModel.selectedEntry = entry
                                    }
                                }
                                .contextMenu {
                                    Button("Copy Full Command") {
                                        PasteboardHelper.copy("\(entry.command) \(entry.arguments)")
                                    }
                                    Button("Copy Arguments") {
                                        PasteboardHelper.copy(entry.arguments)
                                    }
                                    Button("Copy Client Address") {
                                        PasteboardHelper.copy(entry.client)
                                    }
                                    Divider()
                                    Button("Filter by this Command (\(entry.command))") {
                                        viewModel.filterCommand = entry.command
                                    }
                                    Button("Filter by this Client (\(entry.client))") {
                                        viewModel.filterClient = entry.client
                                    }
                                }

                                Divider()
                            }
                        }
                    }
                    .onChange(of: items.first?.id) { _, _ in
                        if viewModel.isAutoScrollEnabled, let firstId = items.first?.id {
                            proxy.scrollTo(firstId, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Detail Inspector Drawer

    private func detailInspector(_ entry: MonitorCommandEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(entry.command)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(commandColor(entry.command))

                    Text("DB \(entry.db)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)

                    Text(entry.timestampString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("Client: \(entry.client)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Copy Command") {
                    PasteboardHelper.copy("\(entry.command) \(entry.arguments)")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)

                Button(action: {
                    viewModel.selectedEntry = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(entry.arguments.isEmpty ? "<no arguments>" : entry.arguments)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 60)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func commandColor(_ cmd: String) -> Color {
        switch cmd {
        case "GET", "MGET", "HGET", "HGETALL", "LRANGE", "SMEMBERS", "ZRANGE", "SCAN", "KEYS":
            return .blue
        case "SET", "SETEX", "MSET", "HSET", "LPUSH", "RPUSH", "SADD", "ZADD":
            return .green
        case "DEL", "UNLINK", "HDEL", "LREM", "SREM", "ZREM", "FLUSHDB", "FLUSHALL":
            return .red
        case "EXPIRE", "PEXPIRE", "PERSIST", "TTL", "TYPE", "MEMORY":
            return .orange
        case "PING", "INFO", "MONITOR", "CLIENT", "SELECT", "AUTH":
            return .purple
        default:
            return .primary
        }
    }
}
