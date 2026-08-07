//
//  SettingsStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/2.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import SwiftUI
import Observation

private let logger = Logger(label: "settings-store")

@MainActor
@Observable
final class SettingsViewModel {
    var colorSchemeValue: String = ColorSchemeEnum.SYSTEM.rawValue
    var defaultFavorite: String = "last"
    var stringMaxLength: Int = Const.DEFAULT_STRING_MAX_LENGTH
    var keepalive: Int = 30
    var redisModels: [RedisModel] = []
    var fastPage: Bool = true
    var fastPageMax: Int = 99

    init() {
        logger.info("SettingsViewModel init ...")
        initial()
    }

    func initial() {
        logger.info("settings initial...")

        colorSchemeValue = UserDefaults.standard.string(forKey: UserDefaultsKeysEnum.AppColorScheme.rawValue)
            ?? ColorSchemeEnum.SYSTEM.rawValue

        let stringMaxLengthStr = UserDefaults.standard.string(forKey: UserDefaultsKeysEnum.AppStringMaxLength.rawValue)
        if let s = stringMaxLengthStr {
            stringMaxLength = Int(s) ?? Const.DEFAULT_STRING_MAX_LENGTH
        } else {
            stringMaxLength = Const.DEFAULT_STRING_MAX_LENGTH
        }

        defaultFavorite = UserDefaults.standard.string(forKey: UserDefaultsKeysEnum.RedisFavoriteDefaultSelectType.rawValue)
            ?? RedisFavoriteDefaultSelectTypeEnum.LAST.rawValue

        fastPage = Bool(UserDefaults.standard.string(forKey: UserDefaultsKeysEnum.AppFastPage.rawValue) ?? "true") ?? true

        redisModels = RedisDefaults.getAll()
    }

    func setColorScheme(_ value: String) {
        logger.info("update color scheme, \(value)")
        colorSchemeValue = value
        UserDefaults.standard.set(value, forKey: UserDefaultsKeysEnum.AppColorScheme.rawValue)
    }

    func setDefaultFavorite(_ value: String) {
        logger.info("update default favorite, \(value)")
        defaultFavorite = value
        UserDefaults.standard.set(value, forKey: UserDefaultsKeysEnum.RedisFavoriteDefaultSelectType.rawValue)
    }

    func setStringMaxLength(_ value: Int) {
        logger.info("set stringMaxLength, \(value)")
        stringMaxLength = value
        UserDefaults.standard.set(value, forKey: UserDefaultsKeysEnum.AppStringMaxLength.rawValue)
    }

    func setKeepalive(_ value: Int) {
        logger.info("set keepalive, \(value)")
        keepalive = value
        UserDefaults.standard.set(value, forKey: UserDefaultsKeysEnum.AppKeepalive.rawValue)
    }

    func setFastPage(_ value: Bool) {
        logger.info("set fast page, \(value)")
        fastPage = value
        UserDefaults.standard.set("\(value)", forKey: UserDefaultsKeysEnum.AppFastPage.rawValue)
    }
}
