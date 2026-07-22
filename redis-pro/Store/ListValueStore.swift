//
//  ListValueStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/22.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "list-value-store")

@MainActor
@Observable
final class ListValueViewModel {
    var editModalVisible: Bool = false
    var editValue: String = ""
    // -1: LPUSH, -2: RPUSH, 0: lset (edit)
    var pushType: Int = 0
    var editIndex: Int = -1
    var isNew: Bool = false
    var redisKeyModel: RedisKeyModel?

    let page: PageViewModel
    let table: TableViewModel<RedisListItemModel>

    var onSubmitSuccess: ((Bool) -> Void)?
    var onRefresh: (() -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.page = PageViewModel()
        self.page.showTotal = true
        self.table = TableViewModel<RedisListItemModel>(
            columns: [
                .init(title: "Index", width: 120) { "\($0.index)" },
                .init(title: "Value") { $0.value }
            ],
            datasource: []
        )
        setupTableCallbacks()
        setupPageCallbacks()
        logger.info("ListValueViewModel init ...")
    }

    private func setupTableCallbacks() {
        table.onCopy = { [weak self] index in
            guard let self else { return }
            let item = self.table.datasource[index]
            PasteboardHelper.copy(item.value)
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
        logger.info("list value initial...")
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
                let (res, updatedPage) = try await redisInstance.getClient().pageList(key, page: page)
                self.table.datasource = res
                self.page.current = updatedPage.current
                self.page.size = updatedPage.size
                self.page.total = updatedPage.total
            } catch {
                Messages.show(error)
            }
        }
    }

    func addNew(type: Int) {
        editValue = ""
        editIndex = -1
        isNew = true
        pushType = type
        editModalVisible = true
    }

    func edit(_ index: Int) {
        pushType = 0
        let item = table.datasource[index]
        editIndex = index
        editValue = item.value
        isNew = false
        editModalVisible = true
    }

    func submit() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        let editValue = self.editValue
        let isNewKey = redisKeyModel.isNew
        let pushType = self.pushType
        let item = pushType == 0 ? table.datasource[editIndex] : nil
        Task {
            do {
                if pushType == -1 {
                    let _ = try await redisInstance.getClient().lpush(key, value: editValue)
                } else if pushType == -2 {
                    let _ = try await redisInstance.getClient().rpush(key, value: editValue)
                } else if pushType == 0, let item {
                    let _ = try await redisInstance.getClient().lset(key, index: item.index, value: editValue)
                    logger.info("redis list set success")
                } else {
                    Messages.show("System error!!!")
                    return
                }

                if self.isNew {
                    self.isNew = false
                    self.refresh()
                } else {
                    if let item {
                        let newItem = RedisListItemModel(item.index, editValue)
                        self.table.datasource[self.editIndex] = newItem
                    }
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
                String(format: NSLocalizedString("LIST_DELETE_CONFIRM_TITLE'%@'", comment: ""), item.value),
                message: String(format: NSLocalizedString("LIST_DELETE_CONFIRM_MESSAGE", comment: ""), item.index, item.value),
                primaryButton: "Delete"
            )
            if r { self.deleteKey(index) }
        }
    }

    func deleteKey(_ index: Int) {
        let redisKeyModel = self.redisKeyModel!
        let item = table.datasource[index]
        logger.info("delete list item, key: \(redisKeyModel.key), index: \(item.index)")
        Task {
            do {
                let r = try await redisInstance.getClient().ldel(redisKeyModel.key, index: item.index, value: item.value)
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
