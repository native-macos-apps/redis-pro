//
//  RedisMetricsView.swift
//  redis-pro
//
//  Created for Real-time Server Metrics and Visual Performance Charts.
//

import SwiftUI
import AppKit

struct RedisMetricsView: View {
    @Bindable var viewModel: RedisMetricsViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    chartsGridSection
                    detailedInfoSection
                }
                .padding(16)
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
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Server Metrics")
                    .font(.system(size: 13, weight: .bold))

                // Live status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isPolling ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(viewModel.isPolling ? "Live" : "Paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }

            Spacer()

            // Refresh interval picker
            HStack(spacing: 4) {
                Text("Interval:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.pollInterval) {
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                }
                .pickerStyle(.menu)
                .frame(width: 75)
                .onChange(of: viewModel.pollInterval) { _, _ in
                    if viewModel.isPolling {
                        viewModel.stopPolling()
                        viewModel.startPolling()
                    }
                }
            }

            // Pause / Resume Button
            Button(action: {
                viewModel.togglePolling()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isPolling ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text(viewModel.isPolling ? "Pause" : "Resume")
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

            // Refresh Now Button
            Button(action: {
                viewModel.refreshNow()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                    Text("Refresh")
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Charts Grid Section

    private var chartsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-Time Performance Charts")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                // Chart 1: Throughput (Commands/sec)
                MetricLineChartView(
                    title: "Throughput (ops/s)",
                    currentValueText: "\(viewModel.latestMetrics.instantOpsPerSec) ops/s",
                    history: viewModel.opsHistory,
                    primaryColor: .yellow,
                    primaryLabel: "Instantaneous Ops/sec",
                    secondaryColor: nil,
                    secondaryLabel: nil,
                    unit: "ops/s",
                    valueFormatter: { "\(Int($0))" }
                )

                // Chart 2: Memory Usage (Used vs RSS)
                MetricLineChartView(
                    title: "Memory (Used vs RSS)",
                    currentValueText: "\(viewModel.latestMetrics.usedMemoryHuman) / \(viewModel.latestMetrics.usedMemoryRssHuman)",
                    history: viewModel.memoryHistory,
                    primaryColor: .blue,
                    primaryLabel: "Used Memory (MB)",
                    secondaryColor: .purple,
                    secondaryLabel: "Physical RSS (MB)",
                    unit: "MB",
                    valueFormatter: { String(format: "%.1f MB", $0) }
                )

                // Chart 3: Hit Ratio
                MetricLineChartView(
                    title: "Cache Hit Ratio",
                    currentValueText: String(format: "%.1f%%", viewModel.latestMetrics.hitRatio),
                    history: viewModel.hitRatioHistory,
                    primaryColor: .teal,
                    primaryLabel: "Hit Ratio %",
                    secondaryColor: nil,
                    secondaryLabel: nil,
                    unit: "%",
                    fixedMaxY: 100.0,
                    valueFormatter: { String(format: "%.1f%%", $0) }
                )

                // Chart 4: Clients
                MetricLineChartView(
                    title: "Connected Clients",
                    currentValueText: "\(viewModel.latestMetrics.connectedClients) connected",
                    history: viewModel.clientsHistory,
                    primaryColor: .indigo,
                    primaryLabel: "Connected",
                    secondaryColor: .red,
                    secondaryLabel: "Blocked",
                    unit: "",
                    valueFormatter: { "\(Int($0))" }
                )

                // Chart 5: Network Traffic
                MetricLineChartView(
                    title: "Network Bandwidth",
                    currentValueText: String(format: "In: %.1f KB/s | Out: %.1f KB/s", viewModel.latestMetrics.instantInputKbps, viewModel.latestMetrics.instantOutputKbps),
                    history: viewModel.networkHistory,
                    primaryColor: .green,
                    primaryLabel: "Input (KB/s)",
                    secondaryColor: .orange,
                    secondaryLabel: "Output (KB/s)",
                    unit: "KB/s",
                    valueFormatter: { String(format: "%.1f", $0) }
                )

                // Chart 6: Memory Fragmentation & Waste
                MetricLineChartView(
                    title: "Fragmentation Ratio & Waste",
                    currentValueText: String(format: "Ratio: %.2f | Waste: %@", viewModel.latestMetrics.fragmentationRatio, viewModel.latestMetrics.wasteBytesHuman),
                    history: viewModel.fragHistory,
                    primaryColor: .mint,
                    primaryLabel: "Ratio",
                    secondaryColor: .secondary.opacity(0.8),
                    secondaryLabel: "Waste (MB)",
                    unit: "",
                    valueFormatter: { String(format: "%.2f", $0) }
                )
            }
        }
    }

    // MARK: - Detailed Info Section

    private var detailedInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System & Storage Details")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                // Left Column: Server & Memory details
                VStack(spacing: 12) {
                    detailsCard(title: "Server & Environment", icon: "server.rack") {
                        detailRow(label: "Redis Version", value: viewModel.latestMetrics.redisVersion)
                        detailRow(label: "Operating System", value: viewModel.latestMetrics.os)
                        detailRow(label: "Process ID", value: "\(viewModel.latestMetrics.processId)")
                        detailRow(label: "TCP Port", value: "\(viewModel.latestMetrics.tcpPort)")
                        detailRow(label: "Role", value: viewModel.latestMetrics.role.capitalized)
                        detailRow(label: "Mode", value: viewModel.latestMetrics.redisMode.capitalized)
                        detailRow(label: "Uptime", value: "\(viewModel.latestMetrics.uptimeHuman) (\(viewModel.latestMetrics.uptimeInSeconds)s)")
                    }

                    detailsCard(title: "Memory Allocation", icon: "memorychip") {
                        detailRow(label: "Used Memory", value: viewModel.latestMetrics.usedMemoryHuman)
                        detailRow(label: "Physical RSS", value: viewModel.latestMetrics.usedMemoryRssHuman)
                        detailRow(label: "Peak Memory", value: viewModel.latestMetrics.peakMemoryHuman)
                        detailRow(label: "Lua Engine Memory", value: viewModel.latestMetrics.luaMemoryHuman)
                        detailRow(label: "Max Memory Limit", value: viewModel.latestMetrics.maxMemoryHuman)
                        detailRow(label: "Max Memory Policy", value: viewModel.latestMetrics.maxMemoryPolicy)
                        detailRow(label: "Memory Allocator", value: viewModel.latestMetrics.memAllocator)
                        detailRow(label: "Fragmentation Ratio", value: String(format: "%.2f", viewModel.latestMetrics.fragmentationRatio))
                        detailRow(label: "Estimated Waste", value: viewModel.latestMetrics.wasteBytesHuman)
                    }
                }

                // Right Column: Keyspace & Persistence details
                VStack(spacing: 12) {
                    detailsCard(title: "Keyspace by Database", icon: "cylinder.split.1x2") {
                        if viewModel.latestMetrics.keyspaceDbs.isEmpty {
                            Text("No active keyspace info detected")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            HStack {
                                Text("DB")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 50, alignment: .leading)
                                Text("Keys")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 70, alignment: .trailing)
                                Text("Expiring")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 70, alignment: .trailing)
                                Text("Avg TTL")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .foregroundStyle(.secondary)

                            Divider()

                            ForEach(viewModel.latestMetrics.keyspaceDbs) { db in
                                HStack {
                                    Text(db.dbName)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .frame(width: 50, alignment: .leading)
                                    Text("\(db.keys.formatted())")
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 70, alignment: .trailing)
                                    Text("\(db.expires.formatted())")
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 70, alignment: .trailing)
                                    Text(db.avgTtl > 0 ? "\(db.avgTtl)ms" : "-")
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    detailsCard(title: "Persistence & Activity", icon: "arrow.triangle.2.circlepath") {
                        detailRow(label: "RDB Last Save Status", value: viewModel.latestMetrics.rdbLastBgsaveStatus)
                        detailRow(label: "RDB Pending Changes", value: "\(viewModel.latestMetrics.rdbChangesSinceLastSave)")
                        detailRow(label: "RDB Last Save Duration", value: "\(viewModel.latestMetrics.rdbLastBgsaveTimeSec)s")
                        detailRow(label: "AOF Enabled", value: viewModel.latestMetrics.aofEnabled ? "Yes" : "No")
                        detailRow(label: "Total Commands", value: viewModel.latestMetrics.totalCommandsProcessed.formatted())
                        detailRow(label: "Total Connections", value: viewModel.latestMetrics.totalConnectionsReceived.formatted())
                        detailRow(label: "Rejected Connections", value: "\(viewModel.latestMetrics.rejectedConnections)")
                        detailRow(label: "Total Evictions", value: "\(viewModel.latestMetrics.evictedKeys)")
                    }
                }
            }
        }
    }

    private func detailsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
            }

            Divider()

            content()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Reusable Metric Line Chart Component

struct MetricLineChartView: View {
    let title: String
    let currentValueText: String
    let history: [MetricDataPoint]
    let primaryColor: Color
    let primaryLabel: String
    let secondaryColor: Color?
    let secondaryLabel: String?
    let unit: String
    var fixedMaxY: Double? = nil
    var valueFormatter: (Double) -> String = { "\(Int($0))" }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Title, Legend, and Current Value Badge
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Current value
                Text(currentValueText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(primaryColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Legend labels if secondary present
            if let secColor = secondaryColor, let secLabel = secondaryLabel {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(primaryColor).frame(width: 6, height: 6)
                        Text(primaryLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle().fill(secColor).frame(width: 6, height: 6)
                        Text(secLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            // Chart area
            GeometryReader { geo in
                let labelWidth: CGFloat = 38
                let bottomLabelHeight: CGFloat = 16
                let plotWidth = max(10, geo.size.width - labelWidth - 8)
                let plotHeight = max(10, geo.size.height - bottomLabelHeight - 6)

                let effectivePoints: [MetricDataPoint] = {
                    if history.count >= 2 {
                        return history
                    } else if let single = history.first {
                        let now = Date()
                        return [
                            MetricDataPoint(timestamp: now.addingTimeInterval(-60), value: single.value, secondaryValue: single.secondaryValue),
                            single
                        ]
                    } else {
                        let now = Date()
                        return [
                            MetricDataPoint(timestamp: now.addingTimeInterval(-60), value: 0),
                            MetricDataPoint(timestamp: now, value: 0)
                        ]
                    }
                }()

                let primaryMax = effectivePoints.map(\.value).max() ?? 0.0
                let secondaryMax = effectivePoints.compactMap(\.secondaryValue).max() ?? 0.0
                let rawMax = max(primaryMax, secondaryMax)

                let maxY: Double = {
                    if let fixed = fixedMaxY {
                        return max(fixed, rawMax)
                    }
                    if rawMax <= 0 { return 10.0 }
                    let ceiling = ceil(rawMax * 1.2)
                    return max(5.0, ceiling)
                }()

                let yTicks: [Double] = [maxY, maxY * 0.5, 0.0]

                ZStack(alignment: .topLeading) {
                    // Y-Axis Grid Lines & Labels
                    ForEach(yTicks, id: \.self) { val in
                        let yPos = plotHeight * CGFloat(1.0 - (val / maxY))

                        Text(valueFormatter(val))
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

                    // Primary Area Gradient Fill
                    Path { path in
                        guard !effectivePoints.isEmpty else { return }
                        let startX = labelWidth + 4
                        path.move(to: CGPoint(x: startX, y: plotHeight))

                        for (index, pt) in effectivePoints.enumerated() {
                            let xFactor = CGFloat(index) / CGFloat(max(1, effectivePoints.count - 1))
                            let x = labelWidth + 4 + xFactor * plotWidth
                            let valClamped = min(maxY, max(0.0, pt.value))
                            let y = plotHeight * CGFloat(1.0 - (valClamped / maxY))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        let lastX = labelWidth + 4 + plotWidth
                        path.addLine(to: CGPoint(x: lastX, y: plotHeight))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.2), primaryColor.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Secondary Line Path (if present)
                    if let secColor = secondaryColor {
                        Path { path in
                            for (index, pt) in effectivePoints.enumerated() {
                                let xFactor = CGFloat(index) / CGFloat(max(1, effectivePoints.count - 1))
                                let x = labelWidth + 4 + xFactor * plotWidth
                                let val = pt.secondaryValue ?? 0.0
                                let valClamped = min(maxY, max(0.0, val))
                                let y = plotHeight * CGFloat(1.0 - (valClamped / maxY))

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(secColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }

                    // Primary Line Path
                    Path { path in
                        for (index, pt) in effectivePoints.enumerated() {
                            let xFactor = CGFloat(index) / CGFloat(max(1, effectivePoints.count - 1))
                            let x = labelWidth + 4 + xFactor * plotWidth
                            let valClamped = min(maxY, max(0.0, pt.value))
                            let y = plotHeight * CGFloat(1.0 - (valClamped / maxY))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(primaryColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

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
            .frame(height: 110)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
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
