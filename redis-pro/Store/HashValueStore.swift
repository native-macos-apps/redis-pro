//
//  HashValueStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/14.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "hash-value-store")

@MainActor
@Observable
final class HashValueViewModel {
    var editModalVisible: Bool = false
    var field: String = ""
    var value: String = ""
    var editIndex: Int = -1
    var isNew: Bool = false
    var redisKeyModel: RedisKeyModel?

    let page: PageViewModel
    let table: TableViewModel<RedisHashEntryModel>

    var onSubmitSuccess: ((Bool) -> Void)?
    var onRefresh: (() -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.page = PageViewModel()
        self.page.showTotal = true
        self.table = TableViewModel<RedisHashEntryModel>(
            columns: [
                .init(title: "Field", width: 120) { $0.field },
                .init(title: "Value") { $0.value }
            ],
            datasource: []
        )
        setupTableCallbacks()
        setupPageCallbacks()
        logger.info("HashValueViewModel init ...")
    }

    private func setupTableCallbacks() {
        table.onCopy = { [weak self] index in
            guard let self else { return }
            let item = self.table.datasource[index]
            PasteboardHelper.copy("Field: \(item.field) \n Value: \(item.value)")
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
        logger.info("hash value initial...")
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
                let (res, updatedPage) = try await redisInstance.getClient().pageHash(key, page: page)
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
        field = ""
        value = ""
        isNew = true
        editModalVisible = true
    }

    func edit(_ index: Int) {
        let item = table.datasource[index]
        editIndex = index
        field = item.field
        value = item.value
        isNew = false
        editModalVisible = true
    }

    func submit() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        let field = self.field
        let value = self.value
        let isNewKey = redisKeyModel.isNew
        Task {
            do {
                _ = try await redisInstance.getClient().hset(key: key, field: field, value: value)
                let item = RedisHashEntryModel(field: field, value: value)
                if self.isNew {
                    self.table.selectIndex = 0
                    self.table.datasource.insert(item, at: 0)
                    self.isNew = false
                } else {
                    self.table.datasource[self.editIndex] = item
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
                String(format: NSLocalizedString("HASH_DELETE_CONFIRM_TITLE'%@'", comment: ""), item.field),
                message: String(format: NSLocalizedString("HASH_DELETE_CONFIRM_MESSAGE'%@'", comment: ""), item.field),
                primaryButton: "Delete"
            )
            if r { self.deleteKey(index) }
        }
    }

    func deleteKey(_ index: Int) {
        let redisKeyModel = self.redisKeyModel!
        let item = table.datasource[index]
        logger.info("delete hash field, key: \(redisKeyModel.key), field: \(item.field)")
        Task {
            do {
                let r = try await redisInstance.getClient().hdel(key: redisKeyModel.key, fields: [item.field])
                logger.info("do delete hash field, r:\(r)")
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
