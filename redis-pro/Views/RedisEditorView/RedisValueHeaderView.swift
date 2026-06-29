//
//  RedisValueHeaderView.swift
//  redis-pro
//
//  Liquid Glass key editor toolbar.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct RedisValueHeaderView: View {

    @State var viewModel: KeyViewModel
    private static let logger = Logger(label: "redis-value-header")

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Key field
            FormItemText(
                label: "Key",
                labelWidth: 36,
                required: true,
                editable: viewModel.isNew,
                value: Binding(get: { viewModel.key }, set: { viewModel.key = $0 })
            )
            .frame(maxWidth: .infinity)
            .font(.system(.body, design: .monospaced))

            // Type picker
            RedisKeyTypePicker(
                label: "Type",
                value: Binding(get: { viewModel.type }, set: { viewModel.type = $0 }),
                disabled: !viewModel.isNew
            )

            // TTL field
            ttlView
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(in: .rect)
    }

    private var ttlView: some View {
        HStack(spacing: 6) {
            FormItemInt(
                label: "TTL(s)",
                labelWidth: 46,
                value: Binding(get: { viewModel.ttl }, set: { viewModel.ttl = $0 }),
                suffix: "square.and.pencil",
                onCommit: { viewModel.submit() }
            )
            .disabled(viewModel.isNew)
            .help("TTL in seconds, -1 = no expiry")
            .frame(width: 180)

            // TTL indicator chip
            if !viewModel.isNew {
                ttlBadge
            }
        }
    }

    @ViewBuilder
    private var ttlBadge: some View {
        let ttl = viewModel.ttl
        if ttl == -1 {
            Label("No Expiry", systemImage: "infinity")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.green.opacity(0.1), in: Capsule())
        } else if ttl > 0 {
            Label("\(ttl)s", systemImage: "clock")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ttl < 60 ? Color.red : Color.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((ttl < 60 ? Color.red : Color.orange).opacity(0.1), in: Capsule())
        }
    }
}
