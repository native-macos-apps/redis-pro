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
            HStack(spacing: 2) {
                Text("Encoding:")
                    .font(.system(.body))
                    .foregroundColor(.primary)
                
                Text(viewModel.encoding.isEmpty ? "–" : viewModel.encoding)
                    .font(.system(.body))
                    .foregroundColor(.secondary)
                    .help("Internal Redis encoding")
            }
            
            HStack(spacing: 2) {
                Text("Memory:")
                    .font(.system(.body))
                    .foregroundColor(.primary)
                
                Text(viewModel.memorySize)
                    .font(.system(.body))
                    .foregroundColor(.secondary)
                    .help("Memory usage (approximate)")
            }
        }
        .padding(.horizontal, 10)
    }
}
