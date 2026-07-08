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
    @State private var isEditingTTL = false
    @State private var tempTTL: Int = -1
    
    private static let logger = Logger(label: "redis-value-header")

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(viewModel.key)
                .textSelection(.enabled)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .opacity(0.8)
                .font(.system(.body, design: .monospaced))
            
            // TTL display with click-to-edit popover
            HStack(spacing: 4) {
                Text("TTL:")
                    .font(.body)

                Button(action: {
                    tempTTL = viewModel.ttl
                    isEditingTTL = true
                }) {
                    HStack(spacing: 4) {
                        Text(viewModel.ttl == -1 ? "-1 (Never)" : "\(viewModel.ttl)s")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .help("Click to edit TTL")
                .popover(isPresented: $isEditingTTL, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Edit TTL (seconds)")
                            .font(.headline)
                        
                        TextField("", value: $tempTTL, formatter: NumberHelper.intFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onSubmit {
                                commitTTL()
                            }
                        
                        HStack {
                            Button("Confirm") {
                                commitTTL()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Cancel") {
                                isEditingTTL = false
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                    .frame(width: 200)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func commitTTL() {
        viewModel.ttl = tempTTL
        viewModel.submit()
        isEditingTTL = false
    }
}
