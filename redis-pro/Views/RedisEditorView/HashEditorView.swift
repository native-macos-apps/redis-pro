//
//  HashEditorView.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/4/9.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct HashEditorView: View {
    @State var viewModel: ValueViewModel
    private let logger = Logger(label: "redis-hash-editor")

    var body: some View {
        let vm = viewModel.hashValue
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Button(action: { vm.addNew() }) {
                    Label("Add", systemImage: "plus")
                }

                SearchBar(placeholder: "Search field...", onCommit: { vm.search($0) })
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
                    let item = vm.table.datasource[index]
                    PasteboardHelper.copy(item.field)
                } label: {
                    Label("Copy Field", systemImage: "doc.on.doc")
                }

                Button {
                    let item = vm.table.datasource[index]
                    PasteboardHelper.copy(item.value)
                } label: {
                    Label("Copy Value", systemImage: "doc.on.doc")
                }

                Divider()

                Button {
                    vm.table.copy(index: index)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c")
            }
        }
        .onAppear {
            logger.info("redis hash editor view appear ...")
            vm.initial()
        }
        .sheet(isPresented: Binding(get: { vm.editModalVisible }, set: { vm.editModalVisible = $0 })) {
            ModalView("Edit hash entry", action: { vm.submit() }) {
                VStack(alignment: .leading, spacing: 8) {
                    FormItemText(placeholder: "Field", editable: vm.isNew, value: Binding(get: { vm.field }, set: { vm.field = $0 }))
                    FormItemTextArea(placeholder: "Value", value: Binding(get: { vm.value }, set: { vm.value = $0 }))
                }
            }
        }
    }
}
