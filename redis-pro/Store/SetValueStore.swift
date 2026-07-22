//
//  SetValueStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/22.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "set-value-store")

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@MainActor
@Observable
final class SetValueViewModel {
    var editModalVisible: Bool = false
    var editValue: String = ""
    var editIndex: Int = -1
    var isNew: Bool = false
    var redisKeyModel: RedisKeyModel?

    let page: PageViewModel
    let table: TableViewModel<String>

    var onSubmitSuccess: ((Bool) -> Void)?
    var onRefresh: (() -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.page = PageViewModel()
        self.page.showTotal = true
        self.table = TableViewModel<String>(
            columns: [
                .init(title: "Value") { $0 }
            ],
            datasource: []
        )
        setupTableCallbacks()
        setupPageCallbacks()
        logger.info("SetValueViewModel init ...")
    }

    private func setupTableCallbacks() {
        table.onCopy = { [weak self] index in
            guard let self else { return }
            PasteboardHelper.copy(self.table.datasource[index])
        }
        table.onDouble = { [weak self] index in self?.edit(index) }
        table.onDelete = { [weak self] index in self?.deleteConfirm(index) }
    }

    private func setupPageCallbacks() {
        page.onNextPage = { [weak self] in self?.getValue() }
        page.onPrevPage = { [weak self] in self?.getValue() }
        page.onUpdateSize = { [weak self] in self?.getValue() }
    }

    func initial() {
        page.keywords = ""
        page.current = 1
        logger.info("set value initial...")
        getValue()
    }

    func refresh() {
        getValue()
        onRefresh?()
    }

    func search(_ keywords: String) {
        page.current = 1
        page.keywords = keywords
        getValue()
    }

    func getValue() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        
        let current = self.page.current
        let size = self.page.size
        let keywords = self.page.keywords
        Task {
            do {
                var page = Page()
                page.current = current
                page.size = size
                page.keywords = keywords
                let (res, updatedPage) = try await redisInstance.getClient().pageSet(key, page: page)
                self.table.datasource = res
                self.page.current = updatedPage.current
                self.page.size = updatedPage.size
                self.page.total = updatedPage.total
            } catch {
                Messages.show(error)
            }
        }
    }

    func addNew() {
        editValue = ""
        editIndex = -1
        isNew = true
        editModalVisible = true
    }

    func edit(_ index: Int) {
        let item = table.datasource[index]
        editIndex = index
        editValue = item
        isNew = false
        editModalVisible = true
    }

    func submit() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        let editValue = self.editValue
        let isNewAction = self.isNew
        let isNewKey = redisKeyModel.isNew
        let originEle = isNewAction ? nil : table.datasource[editIndex]
        Task {
            do {
                if isNewAction {
                    let _ = try await redisInstance.getClient().sadd(key, ele: editValue)
                    self.table.selectIndex = 0
                    self.table.datasource.insert(editValue, at: 0)
                } else {
                    let _ = try await redisInstance.getClient().supdate(key, from: originEle!, to: editValue)
                    self.table.datasource[self.editIndex] = editValue
                }
                self.onSubmitSuccess?(isNewKey)
            } catch {
                Messages.show(error)
            }
        }
    }

    func deleteConfirm(_ index: Int) {
        guard index < table.datasource.count else { return }
        let item = table.datasource[index]
        Task {
            let r = await Messages.confirmAsync(
                String(format: NSLocalizedString("SET_DELETE_CONFIRM_TITLE", comment: ""), item),
                message: String(format: NSLocalizedString("SET_DELETE_CONFIRM_MESSAGE", comment: ""), item),
                primaryButton: "Delete"
            )
            if r { self.deleteKey(index) }
        }
    }

    func deleteKey(_ index: Int) {
        let redisKeyModel = self.redisKeyModel!
        let item = table.datasource[index]
        logger.info("delete set item, key: \(redisKeyModel.key), value: \(item)")
        Task {
            do {
                let r = try await redisInstance.getClient().srem(redisKeyModel.key, ele: item)
                if r > 0 {
                    self.table.datasource.remove(at: index)
                    self.refresh()
                }
            } catch {
                Messages.show(error)
            }
        }
    }
}
