//
//  DatabasePicker.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/5/10.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI

struct DatabasePicker: View {

    @State var viewModel: DatabaseViewModel

    var body: some View {
        Menu(content: {
            ForEach(0 ..< viewModel.databases, id: \.self) { item in
                Button("DB \(item)", action: { viewModel.selectDB(item) })
                    .font(.system(.body))
                    .foregroundColor(.primary)
            }
        }, label: {
            Text("DB \(viewModel.database)").font(.system(.body))
        })
        .onAppear {
            viewModel.initial()
        }
    }
}
