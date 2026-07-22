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

    @State var viewModel: ValueViewModel
    @State private var isEditingTTL = false
    @State private var tempTTL: Int = -1
    
    private static let logger = Logger(label: "redis-value-header")

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(viewModel.key.key)
                .textSelection(.enabled)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .opacity(0.8)
                .font(.system(.body, design: .monospaced))
            
            Button(action: {
                viewModel.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")

            // TTL display with click-to-edit popover
            HStack(spacing: 4) {
                Text("TTL:")
                    .font(.body)

                Button(action: {
                    tempTTL = viewModel.key.ttl
                    isEditingTTL = true
                }) {
                    HStack {
                        Text(viewModel.key.ttl == -1 ? "-1 (Never)" : "\(viewModel.key.ttl)s")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        viewModel.key.ttl = tempTTL
        viewModel.key.submit()
        isEditingTTL = false
    }
}
