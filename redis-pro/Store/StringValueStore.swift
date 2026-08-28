//
//  StringValueStore.swift
//  redis-pro
//
//  Created by chengpanwang on 2022/5/6.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation

import Observation

private let logger = Logger(label: "string-value-store")

enum StringViewMode: String, CaseIterable {
    case plain = "Plain Text"
    case json = "JSON"
}

@MainActor
@Observable
final class StringValueViewModel {
    var redisKeyModel: RedisKeyModel?
    var isIntactString: Bool = true
    var length: Int = -1
    var text: String = ""
    var viewMode: StringViewMode = .plain

    // Callback for submit success
    var onSubmitSuccess: ((Bool) -> Void)?
    var onRefresh: (() -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("StringValueViewModel init ...")
    }

    func initial() {
        logger.info("string value initial...")
        Task { await getLength() }
    }

    func getLength() async {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        do {
            let r = try await redisInstance.getClient().strLen(key)
            await updateLength(r)
        } catch {
            Messages.show(error)
        }
    }

    func getValue() async {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        do {
            let r = try await redisInstance.getClient().get(key)
            text = r
        } catch {
            Messages.show(error)
        }
    }

    func submit() {
        guard let redisKeyModel = redisKeyModel else { return }
        let key = redisKeyModel.key
        let isNew = redisKeyModel.isNew
        let text = self.text
        Task {
            do {
                try await redisInstance.getClient().set(key, value: text)
                onSubmitSuccess?(isNew)
            } catch {
                Messages.show(error)
            }
        }
    }

    func updateLength(_ length: Int) async {
        self.length = length
        self.isIntactString = true
        await getValue()
    }


    func refresh() {
        Task { await getLength() }
        onRefresh?()
    }
}
