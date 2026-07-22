//
//  IndexView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/8.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct IndexView: View {
    private static let logger = Logger(label: "index-view")

    @State var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LoginView(viewModel: viewModel)
            .onChange(of: viewModel.isConnect) { oldValue, newValue in
                if newValue {
                    // Connected: Open Workspace window and close this Login window
                    openWindow(id: "workspace-window", value: viewModel.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .textFieldStyle(.roundedBorder)
    }
}
