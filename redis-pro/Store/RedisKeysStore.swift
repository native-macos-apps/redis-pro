//
//  RedisKeysStore.swift
//  redis-pro
//
//  Created by chengpanwang on 2022/5/6.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import SwiftUI
import Observation

private let logger = Logger(label: "redisKeys-store")

@MainActor
@Observable
final class RedisKeysViewModel {
    var database: Int = 0
    var dbsize: Int = 0
    var mainViewType: MainViewTypeEnum = .EDITOR
    var redisKeyNodes: [RedisKeyNode] = []
    var selectedKeyId: String? = nil
    var isLoadingMore: Bool = false
    var hasMoreKeys: Bool = true

    let table: TableViewModel<RedisKeyModel>
    let value: ValueViewModel
    let database_: DatabaseViewModel
    let page: PageViewModel
    let rename: RenameViewModel
    let commandQuery: CommandQueryViewModel
    let addKey: AddKeyViewModel
    let analysis: RedisAnalysisViewModel
    let monitor: RedisMonitorViewModel

    private let redisInstance: RedisInstanceModel

    var redisModel: RedisModel {
        redisInstance.redisModel
    }

    // Debounce/cancel support
    private var searchTask: Task<Void, Never>?
    private var getKeysTask: Task<Void, Never>?
    private var scanCursor: Int = 0

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.table = TableViewModel<RedisKeyModel>(
            columns: [
                .init(title: "Type", width: 40) { $0.type },
                .init(title: "Key", width: 50) { $0.key }
            ],
            datasource: [],
            multiSelect: true
        )
        self.value = ValueViewModel(redisInstance: redisInstance)
        self.database_ = DatabaseViewModel(redisInstance: redisInstance)
        self.page = PageViewModel()
        self.rename = RenameViewModel(redisInstance: redisInstance)
        self.commandQuery = CommandQueryViewModel(redisInstance: redisInstance)
        self.addKey = AddKeyViewModel(redisInstance: redisInstance)
        self.analysis = RedisAnalysisViewModel(redisInstance: redisInstance)
        self.monitor = RedisMonitorViewModel(redisInstance: redisInstance)

        setupCallbacks()
        logger.info("RedisKeysViewModel init ...")
    }

    private func setupCallbacks() {
        // Table callbacks
        table.onSelectionChange = { [weak self] index, _ in
            guard let self else { return }
            self.onKeyChange(index)
        }
        table.onCopy = { [weak self] index in
            guard let self else { return }
            let item = self.table.datasource[index]
            PasteboardHelper.copy(item.key)
        }
        table.onDouble = { [weak self] _ in
            guard let self else { return }
            let redisKeyModel = self.table.datasource[self.table.selectIndex]
            self.rename.key = redisKeyModel.key
            self.rename.newKey = redisKeyModel.key
            self.rename.index = self.table.selectIndex
            self.rename.visible = true
        }
        table.onDelete = { [weak self] index in self?.deleteConfirm([index]) }

        // Database callbacks
        database_.onDBChange = { [weak self] db in
            guard let self else { return }
            // Reset selection and value state to prevent accessing old keys in new database
            self.table.selectIndex = -1
            self.table.selectIndexes = []
            self.table.datasource = []
            self.redisKeyNodes = []
            self.selectedKeyId = nil
            self.value.key.redisKeyModel = RedisKeyModel()
            self.mainViewType = .EDITOR
            self.analysis.stop()
            self.monitor.stop()
            self.page.total = 0
            self.page.current = 1
            self.scanCursor = 0
            self.hasMoreKeys = true
            self.isLoadingMore = false
        }
        database_.onSelectDBSuccess = { [weak self] db in
            logger.info("database switch success, reload keys for database \(db)")
            self?.initial()
        }

        // Rename callback
        rename.onSetKey = { [weak self] index, newKey in
            guard let self else { return }
            var datasource = self.table.datasource
            let old = datasource[index]
            datasource[index] = RedisKeyModel(newKey, type: old.type)
            self.table.datasource = datasource
            self.selectedKeyId = newKey
            Task {
                let nodes = RedisKeyNode.buildTree(from: datasource)
                self.redisKeyNodes = nodes
            }
        }

        // Value submit success callback (chỉ dùng cho edit hiện tại, không còn isNew flow)
        value.onSubmitSuccess = { _ in }

        // Add key popup callback
        addKey.onSuccess = { [weak self] newKeyModel in
            guard let self else { return }
            self.table.datasource.insert(newKeyModel, at: 0)
            let datasource = self.table.datasource
            self.selectedKeyId = newKeyModel.key
            self.value.keyChange(newKeyModel)
            self.mainViewType = .EDITOR
            Task {
                let nodes = RedisKeyNode.buildTree(from: datasource)
                self.redisKeyNodes = nodes
                await self.dbsize()
            }
        }

    }

    // MARK: - Public API

    func initial() {
        logger.info("redis keys initial...")
        search(page.keywords)
        Task { await dbsize() }
    }

    func dbsize() async {
        do {
            let r = try await redisInstance.getClient().dbsize()
            dbsize = r
        } catch {
            Messages.show(error)
        }
    }

    func refresh() {
        initial()
    }

    func refreshCount() {
        Task { await dbsize() }
    }

    func search(_ keywords: String) {
        page.current = 1
        page.total = 0
        page.keywords = keywords
        table.datasource = []
        redisKeyNodes = []
        table.selectIndex = -1
        table.selectIndexes = []
        selectedKeyId = nil
        scanCursor = 0
        hasMoreKeys = true
        isLoadingMore = false

        // Cancel running tasks
        getKeysTask?.cancel()

        getKeys()
    }

    func searchChange(_ keywords: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            search(keywords)
        }
    }

    func getKeys() {
        let size = self.page.size
        let keywords = self.page.keywords
        let cursor = self.scanCursor
        let shouldAppend = !self.table.datasource.isEmpty
        isLoadingMore = shouldAppend
        getKeysTask?.cancel()
        getKeysTask = Task {
            do {
                let result = try await redisInstance.getClient().loadKeys(
                    cursor: cursor,
                    keywords: keywords,
                    count: size
                )
                guard !Task.isCancelled else { return }
                let datasource = shouldAppend
                    ? mergeKeys(existing: self.table.datasource, incoming: result.keys)
                    : result.keys
                self.scanCursor = result.cursor
                self.table.datasource = datasource
                self.redisKeyNodes = RedisKeyNode.buildTree(from: datasource)
                self.hasMoreKeys = result.cursor != 0
                self.isLoadingMore = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoadingMore = false
                Messages.show(error)
            }
        }
    }

    func loadMoreKeysIfNeeded() {
        guard hasMoreKeys, !isLoadingMore else { return }
        getKeys()
    }

    func setMainViewType(_ type: MainViewTypeEnum) {
        mainViewType = type
    }

    func selectCommandQuery() {
        selectedKeyId = nil
        mainViewType = .QUERY
    }

    func selectAnalysis() {
        selectedKeyId = nil
        mainViewType = .ANALYSIS
    }

    func selectMonitor() {
        selectedKeyId = nil
        mainViewType = .MONITOR
    }

    func addNew() {
        addKey.open()
    }

    func selectNode(_ keyId: String?) {
        selectedKeyId = keyId
        if let keyId,
           let index = table.datasource.firstIndex(where: { $0.key == keyId }) {
            table.selectIndex = index
            table.selectIndexes = [index]
            let redisKeyModel = table.datasource[index]
            value.keyChange(redisKeyModel)
            mainViewType = .EDITOR
        } else {
            table.selectIndex = -1
            table.selectIndexes = []
        }
    }

    func onKeyChange(_ index: Int) {
        guard index > -1, index < table.datasource.count else {
            logger.info("onKeyChange: invalid index \(index)")
            return
        }
        mainViewType = .EDITOR
        let redisKeyModel = table.datasource[index]
        value.keyChange(redisKeyModel)
    }

    func deleteConfirm(_ indexes: [Int]) {
        guard !indexes.isEmpty && !table.isEmpty else { return }
        let redisKeys = indexes.map { table.datasource[$0] }
        let msg = (redisKeys.count > 3
            ? [redisKeys[0].key, "...", redisKeys[redisKeys.count - 1].key]
            : redisKeys.map { $0.key }
        ).joined(separator: "\n")

        Task {
            let r = await Messages.confirmAsync(
                String(format: NSLocalizedString("REDIS_KEY_DELETE_CONFIRM_TITLE'%@'", comment: ""), "\(redisKeys.count)"),
                message: String(format: NSLocalizedString("REDIS_KEY_DELETE_CONFIRM_MESSAGE'%@'", comment: ""), msg),
                primaryButton: "Delete"
            )
            if r { self.deleteKey(indexes) }
        }
    }

    func deleteNodeConfirm(_ node: RedisKeyNode) {
        let indexes: [Int]
        if node.isFolder {
            let prefix = node.fullName + ":"
            indexes = table.datasource.enumerated()
                .filter { $0.element.key == node.fullName || $0.element.key.hasPrefix(prefix) }
                .map { $0.offset }
        } else {
            if let index = table.datasource.firstIndex(where: { $0.key == node.fullName }) {
                indexes = [index]
            } else {
                indexes = []
            }
        }

        guard !indexes.isEmpty else { return }
        deleteConfirm(indexes)
    }

    func copyValue(_ node: RedisKeyNode) {
        Task {
            do {
                let value = try await redisInstance.getClient().getValue(node.fullName, type: node.type ?? "string")
                PasteboardHelper.copy(value)
            } catch {
                Messages.show(error)
            }
        }
    }

    func deleteKey(_ indexes: [Int]) {
        let redisKeys = indexes.map { table.datasource[$0] }
        logger.info("delete key: \(indexes)")
        Task {
            do {
                let r = try await redisInstance.getClient().del(redisKeys.map { $0.key })
                logger.info("on delete redis key: \(indexes), r:\(r)")
                if r > 0 {
                    self.deleteSuccess(indexes)
                }
            } catch {
                Messages.show(error)
            }
        }
    }

    func deleteSuccess(_ indexes: [Int]) {
        indexes.sorted(by: >).forEach { table.datasource.remove(at: $0) }
        let datasource = table.datasource
        table.selectIndex = -1
        table.selectIndexes = []
        selectedKeyId = nil
        Task {
            let nodes = RedisKeyNode.buildTree(from: datasource)
            self.redisKeyNodes = nodes
            await self.dbsize()
        }
    }

    func flushDBConfirm() {
        Task {
            let r = await Messages.confirmAsync(
                "Flush DB ?",
                message: "Are you sure you want to flush db? This operation cannot be undone.",
                primaryButton: "Ok"
            )
            if r { self.flushDB() }
        }
    }

    func flushDB() {
        Task {
            do {
                let r = try await redisInstance.getClient().flushDB()
                if r { self.initial() }
            } catch {
                Messages.show(error)
            }
        }
    }

    private func mergeKeys(existing: [RedisKeyModel], incoming: [RedisKeyModel]) -> [RedisKeyModel] {
        guard !existing.isEmpty else { return incoming }
        guard !incoming.isEmpty else { return existing }

        var merged = existing
        var existingKeys = Set(existing.map(\.key))
        for item in incoming where existingKeys.insert(item.key).inserted {
            merged.append(item)
        }
        return merged
    }
}
