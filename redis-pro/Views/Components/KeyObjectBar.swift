//
//  KeyObjectBar.swift
//  redis-pro
//
//  Created by chengpan on 2023/7/30.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct KeyObjectBar: View {
    let viewModel: KeyObjectViewModel

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Encoding:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.encoding.isEmpty ? "–" : viewModel.encoding)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .help("Internal Redis encoding")
            }
            
            HStack(spacing: 4) {
                Text("Memory:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.memorySize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .help("Memory usage (approximate)")
            }
        }
        .padding(.horizontal, 4)
    }
}
