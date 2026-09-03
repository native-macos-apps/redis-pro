//
//  RedisMonitorView.swift
//  redis-pro
//
//  Created for Real-time Live Monitor and Server Metrics.
//

import SwiftUI
import AppKit

struct RedisMonitorView: View {
    @Bindable var viewModel: RedisMonitorViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            metricsHeader
            Divider()
            commandChartSection
            Divider()
            liveCommandTable
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
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Live Monitor")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            // Filter by keyword
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Filter by keyword", text: $viewModel.filterKeyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 140)

                if !viewModel.filterKeyword.isEmpty {
                    Button(action: { viewModel.filterKeyword = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            // Stop / Resume Button
            Button(action: {
                viewModel.toggleMonitoring()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isMonitoring ? "xmark" : "play.fill")
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
            .help("Clear Monitor Logs")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Metrics Header Bar

    private var metricsHeader: some View {
        HStack(spacing: 16) {
            // Memory Card
            HStack(spacing: 8) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory (Used / RSS)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.latestMetrics.usedMemoryHuman) / \(viewModel.latestMetrics.usedMemoryRssHuman)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .help("Used Memory: \(viewModel.latestMetrics.usedMemoryHuman)\nPhysical RSS: \(viewModel.latestMetrics.usedMemoryRssHuman)")

            Divider().frame(height: 22)

            // Commands Card
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Commands")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.latestMetrics.instantOpsPerSec.formatted()) ops/s")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }

            Divider().frame(height: 22)

            // Hit Ratio Card
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hit Ratio")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", viewModel.latestMetrics.hitRatio))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .help("Cache Hit Ratio: \(viewModel.latestMetrics.hits.formatted()) hits / \(viewModel.latestMetrics.misses.formatted()) misses")

            Divider().frame(height: 22)

            // Clients Card
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clients (Conn / Block)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.latestMetrics.connectedClients) / \(viewModel.latestMetrics.blockedClients)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }

            Divider().frame(height: 22)

            // Evicted Keys Card
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.latestMetrics.evictedKeys > 0 ? Color.red : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Evicted Keys")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.latestMetrics.evictedKeys.formatted())")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.latestMetrics.evictedKeys > 0 ? Color.red : Color.primary)
                }
            }
            .help("Keys evicted due to maxmemory limit")

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Live Command Table

    private var liveCommandTable: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 8) {
                Text("Timestamp")
                    .frame(width: 110, alignment: .leading)
                Text("Node")
                    .frame(width: 130, alignment: .leading)
                Text("DB")
                    .frame(width: 40, alignment: .center)
                Text("Client")
                    .frame(width: 140, alignment: .leading)
                Text("Command")
                    .frame(width: 100, alignment: .leading)
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
                        Text("Waiting for commands from Redis server...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Live Monitor is stopped")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { entry in
                            HStack(spacing: 8) {
                                Text(entry.timestampString)
                                    .frame(width: 110, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                Text(entry.node)
                                    .frame(width: 130, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                Text(String(entry.db))
                                    .frame(width: 40, alignment: .center)
                                    .foregroundStyle(.secondary)

                                Text(entry.client)
                                    .frame(width: 140, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                Text(entry.command)
                                    .frame(width: 100, alignment: .leading)
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
                                Rectangle()
                                    .fill(Color.primary.opacity(0.02))
                            )

                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func commandColor(_ cmd: String) -> Color {
        switch cmd {
        case "GET", "MGET", "HGET", "HGETALL", "LRANGE", "SMEMBERS", "ZRANGE":
            return .blue
        case "SET", "SETEX", "MSET", "HSET", "LPUSH", "RPUSH", "SADD", "ZADD":
            return .green
        case "DEL", "UNLINK", "HDEL", "LREM", "SREM", "ZREM", "FLUSHDB", "FLUSHALL":
            return .red
        case "EXPIRE", "PEXPIRE", "PERSIST", "TTL", "TYPE", "MEMORY":
            return .orange
        case "PING", "INFO", "MONITOR", "CLIENT", "SELECT":
            return .purple
        default:
            return .primary
        }
    }

    // MARK: - Command Chart Section

    private var commandChartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Command Rate History")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            CommandLineChart(history: viewModel.commandHistory, latestOps: viewModel.latestMetrics.instantOpsPerSec)
                .frame(height: 90)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Command Line Chart

private struct CommandLineChart: View {
    let history: [CommandHistoryPoint]
    let latestOps: Int

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            let labelWidth: CGFloat = 36
            let bottomLabelHeight: CGFloat = 16
            let plotWidth = max(10, geo.size.width - labelWidth - 8)
            let plotHeight = max(10, geo.size.height - bottomLabelHeight - 6)

            let effectivePoints: [CommandHistoryPoint] = {
                if history.count >= 2 {
                    return history
                } else if let single = history.first {
                    let now = Date()
                    return [
                        CommandHistoryPoint(timestamp: now.addingTimeInterval(-60), ops: single.ops),
                        single
                    ]
                } else {
                    let now = Date()
                    return [
                        CommandHistoryPoint(timestamp: now.addingTimeInterval(-60), ops: latestOps),
                        CommandHistoryPoint(timestamp: now, ops: latestOps)
                    ]
                }
            }()

            let rawMaxOps = effectivePoints.map(\.ops).max() ?? latestOps
            let maxY = max(10.0, ceil(Double(rawMaxOps) * 1.25 / 10.0) * 10.0)
            let yTicks: [Double] = [maxY, maxY * 0.5, 0.0]

            ZStack(alignment: .topLeading) {
                // Y-Axis Labels and Grid Lines
                ForEach(yTicks, id: \.self) { val in
                    let yPos = plotHeight * CGFloat(1.0 - (val / maxY))

                    Text("\(Int(val))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                        .position(x: labelWidth / 2, y: yPos)

                    Path { path in
                        path.move(to: CGPoint(x: labelWidth + 4, y: yPos))
                        path.addLine(to: CGPoint(x: labelWidth + 4 + plotWidth, y: yPos))
                    }
                    .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }

                // Yellow Line Path
                Path { path in
                    for (index, pt) in effectivePoints.enumerated() {
                        let xFactor = CGFloat(index) / CGFloat(max(1, effectivePoints.count - 1))
                        let x = labelWidth + 4 + xFactor * plotWidth
                        let opsClamped = min(maxY, max(0.0, Double(pt.ops)))
                        let y = plotHeight * CGFloat(1.0 - (opsClamped / maxY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // X-Axis Time Labels
                let sampleIndices = calculateSampleIndices(count: effectivePoints.count)
                ForEach(sampleIndices, id: \.self) { idx in
                    let pt = effectivePoints[idx]
                    let xFactor = CGFloat(idx) / CGFloat(max(1, effectivePoints.count - 1))
                    let x = labelWidth + 4 + xFactor * plotWidth
                    let timeStr = Self.timeFormatter.string(from: pt.timestamp)

                    Text(timeStr)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: x, y: plotHeight + 8)
                }
            }
        }
    }

    private func calculateSampleIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        if count <= 4 {
            return Array(0..<count)
        }
        let step = max(1, (count - 1) / 3)
        var indices = [0]
        var curr = step
        while curr < count - 1 {
            indices.append(curr)
            curr += step
        }
        indices.append(count - 1)
        return indices
    }
}
