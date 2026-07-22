//
//  ValueStore.swift
//  redis-pro
//
//  Created by chengpanwang on 2022/5/6.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "value-store")

// MARK: - Protocol

/// Protocol chung cho tất cả value ViewModel.
/// Cho phép ValueViewModel dispatch refresh/initial/setModel
/// mà không cần kiểm tra kiểu tại mỗi call-site.
@MainActor
protocol ValueViewModelProtocol: AnyObject {
    var redisKeyModel: RedisKeyModel? { get set }
    func refresh()
    func initial()
}

extension StringValueViewModel: ValueViewModelProtocol {}
extension HashValueViewModel:   ValueViewModelProtocol {}
extension ListValueViewModel:   ValueViewModelProtocol {}
extension SetValueViewModel:    ValueViewModelProtocol {}
extension ZSetValueViewModel:   ValueViewModelProtocol {}


@MainActor
@Observable
final class ValueViewModel {
    let key: KeyViewModel
    let keyObject: KeyObjectViewModel
    let stringValue: StringValueViewModel
    let hashValue: HashValueViewModel
    let listValue: ListValueViewModel
    let setValue: SetValueViewModel
    let zsetValue: ZSetValueViewModel

    // Active value VM được gán trong keyChange — routing tập trung tại đây
    private var activeValue: (any ValueViewModelProtocol)?

    // Propagate submit success up to parent (RedisKeysViewModel)
    var onSubmitSuccess: ((Bool) -> Void)?

    init(redisInstance: RedisInstanceModel) {
        self.key = KeyViewModel(redisInstance: redisInstance)
        self.keyObject = KeyObjectViewModel(redisInstance: redisInstance)
        self.stringValue = StringValueViewModel(redisInstance: redisInstance)
        self.hashValue = HashValueViewModel(redisInstance: redisInstance)
        self.listValue = ListValueViewModel(redisInstance: redisInstance)
        self.setValue = SetValueViewModel(redisInstance: redisInstance)
        self.zsetValue = ZSetValueViewModel(redisInstance: redisInstance)

        setupCallbacks()
        logger.info("ValueViewModel init ...")
    }

    private func setupCallbacks() {
        let submitHandler: (Bool) -> Void = { [weak self] isNew in
            guard let self else { return }
            if isNew { self.key.isNew = false }
            self.key.refresh()
            self.onSubmitSuccess?(isNew)
        }
        let refreshHandler: () -> Void = { [weak self] in
            self?.key.refresh()
            self?.keyObject.refresh()
        }

        stringValue.onSubmitSuccess = submitHandler
        stringValue.onRefresh = refreshHandler
        hashValue.onSubmitSuccess = submitHandler
        hashValue.onRefresh = refreshHandler
        listValue.onSubmitSuccess = submitHandler
        listValue.onRefresh = refreshHandler
        setValue.onSubmitSuccess = submitHandler
        setValue.onRefresh = refreshHandler
        zsetValue.onSubmitSuccess = submitHandler
        zsetValue.onRefresh = refreshHandler
    }

    func refresh() {
        key.refresh()
        keyObject.refresh()
        activeValue?.refresh()
    }

    func keyChange(_ redisKeyModel: RedisKeyModel) {
        key.redisKeyModel = redisKeyModel
        keyObject.key = redisKeyModel.key

        // Routing duy nhất: gán activeValue theo type
        switch RedisKeyTypeEnum(rawValue: redisKeyModel.type) {
        case .STRING: activeValue = stringValue
        case .HASH:   activeValue = hashValue
        case .LIST:   activeValue = listValue
        case .SET:    activeValue = setValue
        case .ZSET:   activeValue = zsetValue
        default:      activeValue = nil
        }

        activeValue?.redisKeyModel = redisKeyModel
        activeValue?.initial()

        key.refresh()
        keyObject.refresh()
    }

    func setKeyModel(_ redisKeyModel: RedisKeyModel) {
        key.redisKeyModel = redisKeyModel
        activeValue?.redisKeyModel = redisKeyModel
    }
}

