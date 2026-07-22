//
//  RedisValueView.swift
//  redis-pro
//
//  Liquid Glass key value editor container.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI

struct RedisValueView: View {
    @State var viewModel: ValueViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RedisValueHeaderView(viewModel: viewModel)

            Divider()

            RedisValueEditView(viewModel: viewModel)
        }
    }
}
