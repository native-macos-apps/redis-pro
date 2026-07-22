//
//  ZSetValueStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/28.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "zset-value-store")

@MainActor
@Observable
final class ZSetValueViewModel {
    var editModalVisible: Bool = false
    var editValue: String = ""
    var editScore: Double = 0
    var editIndex: Int = -1
    var isNew: Bool = false
    var redisKeyModel: RedisKeyModel?

    var geoModalVisible: Bool = false
    var geoLat: String = ""
    var geoLng: String = ""
    var geoMember: String = ""

    let page: PageViewModel
    let table: TableViewModel<RedisZSetItemModel>

    var onSubmitSuccess: ((Bool) -> Void)?
    var onRefresh: (() -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.page = PageViewModel()
        self.page.showTotal = true
        self.table = TableViewModel<RedisZSetItemModel>(
            columns: [
                .init(title: "Score", width: 120) { $0.score },
                .init(title: "Value") { $0.value }
            ],
            datasource: []
        )
        setupTableCallbacks()
        setupPageCallbacks()
        logger.info("ZSetValueViewModel init ...")
    }

    private func setupTableCallbacks() {
        table.onCopy = { [weak self] index in
            guard let self else { return }
            let item = self.table.datasource[index]
            PasteboardHelper.copy("Score: \(item.score) \nValue: \(item.value)")
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
        logger.info("zset value initial...")
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
        // Capture primitives (not Page) to avoid Swift 6 Sendable error
        let current = self.page.current
        let size = self.page.size
        let keywords = self.page.keywords
        Task {
            do {
                var page = Page()
                page.current = current
                page.size = size
                page.keywords = keywords
                let (res, updatedPage) = try await redisInstance.getClient().pageZSet(key, page: page)
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
        editScore = 0
        editIndex = -1
        isNew = true
        editModalVisible = true
    }

    func edit(_ index: Int) {
        let item = table.datasource[index]
        editIndex = index
        editValue = item.value
        editScore = Double(item.score) ?? 0
        isNew = false
        editModalVisible = true
    }

    func submit() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        let editValue = self.editValue
        let editScore = self.editScore
        let isNewAction = self.isNew
        let isNewKey = redisKeyModel.isNew
        let originEle = isNewAction ? nil : table.datasource[editIndex]
        Task {
            do {
                var r = false
                if isNewAction {
                    r = try await redisInstance.getClient().zadd(key, score: editScore, ele: editValue)
                } else {
                    r = try await redisInstance.getClient().zupdate(key, from: originEle!.value, to: editValue, score: editScore)
                }
                if r {
                    let scoreStr = "\(editScore)"
                    if isNewAction {
                        self.table.selectIndex = 0
                        self.table.datasource.insert(RedisZSetItemModel(value: editValue, score: scoreStr), at: 0)
                    } else {
                        self.table.datasource[self.editIndex] = RedisZSetItemModel(value: editValue, score: scoreStr)
                    }
                    self.onSubmitSuccess?(isNewKey)
                }
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
                StringHelper.format("ZSET_DELETE_CONFIRM_TITLE", item.value),
                message: StringHelper.format("ZSET_DELETE_CONFIRM_MESSAGE", item.value),
                primaryButton: "Delete"
            )
            if r { self.deleteKey(index) }
        }
    }

    func deleteKey(_ index: Int) {
        let redisKeyModel = self.redisKeyModel!
        let item = table.datasource[index]
        logger.info("delete zset item, key: \(redisKeyModel.key), value: \(item.value)")
        Task {
            do {
                let r = try await redisInstance.getClient().zrem(redisKeyModel.key, ele: item.value)
                if r > 0 {
                    self.table.datasource.remove(at: index)
                    self.refresh()
                }
            } catch {
                Messages.show(error)
            }
        }
    }

    func showGeoPos(_ index: Int) {
        guard let redisKeyModel = redisKeyModel else { return }
        let item = table.datasource[index]
        let key = redisKeyModel.key
        let member = item.value
        geoMember = member
        Task {
            do {
                if let pos = try await redisInstance.getClient().geopos(key, member: member) {
                    geoLng = pos[0]
                    geoLat = pos[1]
                    geoModalVisible = true
                } else {
                    Messages.show("No geo position found for member: \(member)")
                }
            } catch {
                Messages.show(error)
            }
        }
    }
}
