//
//  AddKeySheet.swift
//  redis-pro
//
//  Popup sheet để thêm key mới vào Redis.
//  Tách biệt hoàn toàn khỏi detail view, hỗ trợ tất cả 5 type:
//  STRING, HASH, LIST, SET, ZSET
//

import SwiftUI
import Logging

struct AddKeySheet: View {
    @State var viewModel: AddKeyViewModel
    @Environment(\.dismiss) private var dismiss

    private static let logger = Logger(label: "add-key-sheet")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ───────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "plus.rectangle.on.folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("New Key")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.bar)

            Divider()

            // ── Body ─────────────────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Key name + Type row
                    HStack(alignment: .center, spacing: 12) {
                        FormItemText(
                            label: "Key",
                            labelWidth: 46,
                            placeholder: "Enter key name",
                            required: true,
                            value: Binding(
                                get: { viewModel.keyName },
                                set: { viewModel.keyName = $0 }
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .font(.system(.body, design: .monospaced))

                        RedisKeyTypePicker(
                            label: "Type",
                            value: Binding(
                                get: { viewModel.keyType },
                                set: { viewModel.keyType = $0 }
                            )
                        )
                    }

                    Divider()

                    // Dynamic value section theo type
                    valueSection
                }
                .padding(18)
            }

            Divider()

            // ── Footer ───────────────────────────────────────────────────────
            HStack(spacing: 8) {
                // Validation error
                if let error = viewModel.validationError,
                   !viewModel.keyName.isEmpty {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button {
                    viewModel.submit()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                        }
                        Text("Create")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 580, height: sheetHeight)
        .background(.ultraThinMaterial)
    }

    // MARK: - Dynamic value section

    @ViewBuilder
    private var valueSection: some View {
        switch viewModel.keyType {
        case RedisKeyTypeEnum.STRING.rawValue:
            stringSection

        case RedisKeyTypeEnum.HASH.rawValue:
            hashSection

        case RedisKeyTypeEnum.LIST.rawValue:
            listSection

        case RedisKeyTypeEnum.SET.rawValue:
            setSection

        case RedisKeyTypeEnum.ZSET.rawValue:
            zsetSection

        default:
            EmptyView()
        }
    }

    // STRING: một TextArea cho value
    private var stringSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Value", icon: "text.alignleft")
            FormItemTextArea(
                placeholder: "Enter string value",
                value: Binding(
                    get: { viewModel.stringValue },
                    set: { viewModel.stringValue = $0 }
                )
            )
            .frame(minHeight: 90)
        }
    }

    // HASH: field + value
    private var hashSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Initial Entry", icon: "tablecells")
            FormItemText(
                label: "Field",
                labelWidth: 46,
                placeholder: "Enter field name",
                required: true,
                value: Binding(
                    get: { viewModel.hashField },
                    set: { viewModel.hashField = $0 }
                )
            )
            .font(.system(.body, design: .monospaced))

            VStack(alignment: .leading, spacing: 4) {
                FormItemTextArea(
                    label: "Value",
                    labelWidth: 46,
                    placeholder: "Enter field value",
                    value: Binding(
                        get: { viewModel.hashValue },
                        set: { viewModel.hashValue = $0 }
                    )
                )
                .frame(minHeight: 80)
            }
        }
    }

    // LIST: một value (sẽ rpush)
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("First Item", icon: "list.bullet")
            FormItemTextArea(
                placeholder: "Enter list item value",
                value: Binding(
                    get: { viewModel.listValue },
                    set: { viewModel.listValue = $0 }
                )
            )
            .frame(minHeight: 90)
        }
    }

    // SET: một member
    private var setSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("First Member", icon: "circle.grid.3x3")
            FormItemTextArea(
                placeholder: "Enter set member value",
                value: Binding(
                    get: { viewModel.setValue },
                    set: { viewModel.setValue = $0 }
                )
            )
            .frame(minHeight: 90)
        }
    }

    // ZSET: score + member
    private var zsetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("First Member", icon: "chart.bar.xaxis")
            FormItemDouble(
                label: "Score",
                labelWidth: 46,
                placeholder: "0",
                value: Binding(
                    get: { viewModel.zsetScore },
                    set: { viewModel.zsetScore = $0 }
                )
            )
            VStack(alignment: .leading, spacing: 4) {
                FormItemTextArea(
                    label: "Value",
                    labelWidth: 46,
                    placeholder: "Enter member value",
                    value: Binding(
                        get: { viewModel.zsetValue },
                        set: { viewModel.zsetValue = $0 }
                    )
                )
                .frame(minHeight: 80)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var sheetHeight: CGFloat {
        switch viewModel.keyType {
        case RedisKeyTypeEnum.HASH.rawValue,
             RedisKeyTypeEnum.ZSET.rawValue:
            return 400
        default:
            return 340
        }
    }
}
