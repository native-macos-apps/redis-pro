//
//  SetEditorView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/30.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct SetEditorView: View {
    @State var viewModel: ValueViewModel
    let logger = Logger(label: "redis-set-editor")

    var body: some View {
        let vm = viewModel.setValue
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                Button(action: { vm.addNew() }) {
                    Label("Add", systemImage: "plus")
                }

                SearchBar(placeholder: "Search element...", onCommit: { vm.search($0) })
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
        }
        .sheet(isPresented: Binding(get: { vm.editModalVisible }, set: { vm.editModalVisible = $0 })) {
            ModalView("Edit set element", action: { vm.submit() }) {
                VStack(alignment: .leading, spacing: 6) {
                    FormItemTextArea(placeholder: "value", value: Binding(get: { vm.editValue }, set: { vm.editValue = $0 }))
                }
            }
        }
    }
}
