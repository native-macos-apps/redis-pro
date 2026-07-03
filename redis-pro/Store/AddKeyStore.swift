//
//  AddKeyStore.swift
//  redis-pro
//
//  ViewModel riêng cho popup "Add New Key".
//  Tách biệt hoàn toàn khỏi detail view để quản lý code gọn hơn.
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "add-key-store")

@MainActor
@Observable
final class AddKeyViewModel {

    // MARK: - Shared fields
    var isVisible: Bool = false
    var keyName: String = ""
    var keyType: String = RedisKeyTypeEnum.STRING.rawValue

    // MARK: - STRING
    var stringValue: String = ""

    // MARK: - HASH
    var hashField: String = ""
    var hashValue: String = ""

    // MARK: - LIST
    var listValue: String = ""

    // MARK: - SET
    var setValue: String = ""

    // MARK: - ZSET
    var zsetScore: Double = 0
    var zsetValue: String = ""

    // MARK: - Validation
    var isSubmitting: Bool = false

    /// Callback: được gọi khi tạo key thành công, trả về RedisKeyModel vừa tạo
    var onSuccess: ((RedisKeyModel) -> Void)?

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("AddKeyViewModel init ...")
    }

    // MARK: - Public API

    func open() {
        reset()
        isVisible = true
    }

    func close() {
        isVisible = false
    }

    /// Validate input trước khi submit
    var validationError: String? {
        let trimmedKey = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            return "Key name is required"
        }
        switch keyType {
        case RedisKeyTypeEnum.STRING.rawValue:
            break // string value có thể rỗng
        case RedisKeyTypeEnum.HASH.rawValue:
            if hashField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Hash field is required"
            }
        case RedisKeyTypeEnum.LIST.rawValue:
            if listValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "List value is required"
            }
        case RedisKeyTypeEnum.SET.rawValue:
            if setValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Set member is required"
            }
        case RedisKeyTypeEnum.ZSET.rawValue:
            if zsetValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "ZSet member is required"
            }
        default:
            break
        }
        return nil
    }

    var isValid: Bool { validationError == nil }

    func submit() {
        guard isValid, !isSubmitting else { return }
        let key = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = keyType
        isSubmitting = true

        Task {
            do {
                try await performSubmit(key: key, type: type)
                let model = RedisKeyModel(key, type: type)
                self.isSubmitting = false
                self.isVisible = false
                self.onSuccess?(model)
                logger.info("Add new key success: \(key), type: \(type)")
            } catch {
                self.isSubmitting = false
                Messages.show(error)
            }
        }
    }

    // MARK: - Private

    private func performSubmit(key: String, type: String) async throws {
        let client = redisInstance.getClient()
        switch type {
        case RedisKeyTypeEnum.STRING.rawValue:
            try await client.set(key, value: stringValue)

        case RedisKeyTypeEnum.HASH.rawValue:
            _ = try await client.hset(key: key, field: hashField, value: hashValue)

        case RedisKeyTypeEnum.LIST.rawValue:
            _ = try await client.rpush(key, value: listValue)

        case RedisKeyTypeEnum.SET.rawValue:
            _ = try await client.sadd(key, ele: setValue)

        case RedisKeyTypeEnum.ZSET.rawValue:
            _ = try await client.zadd(key, score: zsetScore, ele: zsetValue)

        default:
            throw NSError(domain: "AddKey", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown key type: \(type)"])
        }
    }

    private func reset() {
        keyName = ""
        keyType = RedisKeyTypeEnum.STRING.rawValue
        stringValue = ""
        hashField = ""
        hashValue = ""
        listValue = ""
        setValue = ""
        zsetScore = 0
        zsetValue = ""
        isSubmitting = false
    }
}
