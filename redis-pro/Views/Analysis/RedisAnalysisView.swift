//
//  RedisAnalysisView.swift
//  redis-pro
//
//  Created for Real-time Memory Analysis.
//

import SwiftUI
import AppKit

struct RedisAnalysisView: View {
    @Bindable var viewModel: RedisAnalysisViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    ttlDistributionSection
                    prefixGroupsSection
                }
                .padding(16)
            }

            footerBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Memory Analysis")
                .font(.system(size: 13, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 4) {
                Text("DB Size:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.dbSize.formatted())
                    .font(.system(size: 11, design: .monospaced))
                    .fontWeight(.semibold)
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Est. Commands:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("~\(viewModel.estCommands.formatted())")
                    .font(.system(size: 11, design: .monospaced))
                    .fontWeight(.semibold)
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Policy:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.policy)
                    .font(.system(size: 11, design: .monospaced))
                    .fontWeight(.semibold)
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Progress:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .fontWeight(.semibold)
                if viewModel.isAnalyzing {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Sample:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.sampleSizeOption) {
                    ForEach(SampleSizeOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.mini)
                .frame(width: 105)
                .disabled(viewModel.isAnalyzing)
            }

            Spacer()

            if viewModel.isAnalyzing {
                Button(action: {
                    viewModel.cancelAnalysis()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        Text("Stop")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Stop scanning keys")
            } else {
                Button(action: {
                    viewModel.analyze()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        Text("Analyze")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .help("Analyze Memory & Key TTL Distribution")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
        }
    }

    // MARK: - Section 1: Key TTL Distribution

    private var ttlDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key TTL distribution")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            TTLBarChart(buckets: viewModel.ttlBuckets)
                .frame(height: 150)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.totalSampledCount.formatted()) sampled (≈ \(viewModel.estimatedTotalFromSample.formatted()) estimated) — \(String(format: "%.1f", viewModel.withoutTTLPercent))% without TTL")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(viewModel.largestBucketDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Section 3: Prefix Groups

    private var prefixGroupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Prefix Groups (Top 12)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 8) {
                    Text("Rank by:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.rankBy) {
                        ForEach(RankByOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }

            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: 8) {
                    Text("Prefix")
                        .frame(minWidth: 160, alignment: .leading)
                    Spacer()
                    Text("Est. Key Count")
                        .frame(width: 110, alignment: .trailing)
                    Text("Est. Memory")
                        .frame(width: 100, alignment: .trailing)
                    Text("Avg TTL")
                        .frame(width: 80, alignment: .center)
                    Text("Perm Keys")
                        .frame(width: 90, alignment: .trailing)
                    Text("Types")
                        .frame(width: 120, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))

                Divider()

                let top12 = Array(viewModel.prefixGroups.prefix(12))
                if top12.isEmpty {
                    VStack(spacing: 6) {
                        if viewModel.isAnalyzing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Sampling keys and analyzing memory...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No keys sampled in current database")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                } else {
                    ForEach(Array(top12.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Text(item.prefix)
                                .font(.system(size: 12, design: .monospaced))
                                .fontWeight(.medium)
                                .frame(minWidth: 160, alignment: .leading)
                                .lineLimit(1)

                            Spacer()

                            Text(item.formattedKeyCount)
                                .font(.system(size: 12))
                                .frame(width: 110, alignment: .trailing)

                            Text(item.formattedMemory)
                                .font(.system(size: 12))
                                .frame(width: 100, alignment: .trailing)

                            Text(item.formattedAvgTTL)
                                .font(.system(size: 12))
                                .foregroundStyle(item.formattedAvgTTL == "Perm" ? .secondary : .primary)
                                .frame(width: 80, alignment: .center)

                            Text(item.formattedPermKeys)
                                .font(.system(size: 12))
                                .frame(width: 90, alignment: .trailing)

                            Text(item.typesDisplay)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .trailing)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(index % 2 == 1 ? Color.secondary.opacity(0.04) : Color.clear)

                        if index < top12.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

}

// MARK: - Custom TTL Bar Chart

private struct TTLBarChart: View {
    let buckets: [TTLBucket]

    var body: some View {
        GeometryReader { geo in
            let labelWidth: CGFloat = 46
            let bottomLabelHeight: CGFloat = 22
            let plotWidth = max(10, geo.size.width - labelWidth - 10)
            let plotHeight = max(10, geo.size.height - bottomLabelHeight - 10)

            let maxCount = max(1, buckets.map(\.count).max() ?? 1)
            let yStep = max(1, maxCount / 4)
            let yValues: [Int] = [
                maxCount,
                yStep * 3,
                yStep * 2,
                yStep,
                0
            ]

            ZStack(alignment: .topLeading) {
                // Y-Axis labels & Grid lines
                ForEach(Array(yValues.enumerated()), id: \.offset) { index, val in
                    let factor = CGFloat(index) / 4.0
                    let yPos = plotHeight * factor

                    Text("\(val)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                        .position(x: labelWidth / 2, y: yPos)

                    Path { path in
                        path.move(to: CGPoint(x: labelWidth + 5, y: yPos))
                        path.addLine(to: CGPoint(x: labelWidth + 5 + plotWidth, y: yPos))
                    }
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                }

                // Bars
                let barCount = buckets.count
                if barCount > 0 {
                    let totalSlotWidth = plotWidth / CGFloat(barCount)
                    let barWidth = min(36, totalSlotWidth * 0.5)

                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                        let slotCenterX = labelWidth + 5 + (CGFloat(index) + 0.5) * totalSlotWidth
                        let heightRatio = CGFloat(bucket.count) / CGFloat(maxCount)
                        let barHeight = max(bucket.count > 0 ? 3 : 0, plotHeight * heightRatio)
                        let barY = plotHeight - (barHeight / 2)

                        // Bar rectangle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.55, green: 0.72, blue: 0.95))
                            .frame(width: barWidth, height: barHeight)
                            .position(x: slotCenterX, y: barY)
                            .help("\(bucket.label): \(bucket.count.formatted()) keys (≈ \(bucket.estimatedCount.formatted()) est.)")

                        // X-Axis Label
                        Text(bucket.label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .position(x: slotCenterX, y: plotHeight + 11)
                    }
                }
            }
        }
    }
}
