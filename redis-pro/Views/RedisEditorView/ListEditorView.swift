//
//  ListEditorView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/30.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct ListEditorView: View {
    @State var viewModel: ValueViewModel
    let logger = Logger(label: "redis-list-editor")

    var body: some View {
        let vm = viewModel.listValue
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                Button(action: { vm.addNew(type: -1) }) {
                    Label("Add head", systemImage: "plus")
                }
                Button(action: { vm.addNew(type: -2) }) {
                    Label("Add tail", systemImage: "plus")
                }

                Spacer()
                PageBar(viewModel: vm.page)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            NTableView(viewModel: vm.table) { index in
                Button {
                    vm.edit(index)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .keyboardShortcut("e")

                Button(role: .destructive) {
                    vm.deleteConfirm(index)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete)

                Divider()

                Button {
                    vm.table.copy(index: index)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c")
            }

            // footer
            HStack(alignment: .center, spacing: 0) {
                KeyObjectBar(viewModel: viewModel.keyObject)
                Spacer()
                Button(action: { vm.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                    .padding(.trailing, 8)
            }
            .frame(height: 30)
            .background(.thinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 0.5)
            }
        }
        .sheet(isPresented: Binding(get: { vm.editModalVisible }, set: { vm.editModalVisible = $0 })) {
            ModalView("Edit list item", action: { vm.submit() }) {
                VStack(alignment: .leading, spacing: 6) {
                    FormItemTextArea(label: "", placeholder: "value", value: Binding(get: { vm.editValue }, set: { vm.editValue = $0 }))
                }
            }
        }
    }
}
