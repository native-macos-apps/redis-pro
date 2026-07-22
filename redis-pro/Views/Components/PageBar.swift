//
//  PageBar.swift
//  redis-pro
//
//  Liquid Glass pagination controls.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI

struct PageBar: View {
    @State var viewModel: PageViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if viewModel.showTotal {
                Text("Total: \(viewModel.total)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Picker("", selection: Binding(
                get: { viewModel.size },
                set: { viewModel.updateSize($0) }
            )) {
                Text("10").tag(10)
                Text("50").tag(50)
                Text("100").tag(100)
                Text("200").tag(200)
            }
            .pickerStyle(.menu)
            .frame(width: 60)
            .labelsHidden()

            HStack(spacing: 6) {
                Button {
                    viewModel.prevPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasPrev)

                Text("\(viewModel.current)/\(viewModel.totalPageText)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                Button {
                    viewModel.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasNext)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}
