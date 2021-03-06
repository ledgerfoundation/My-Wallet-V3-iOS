//
//  StaticUbiquitousKeyValueStore.swift
//  PlatformKit
//
//  Created by Paulo on 23/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

/// Provides a way to test usage of UbiquitousKeyValueStore on non-release builds.
class StaticUbiquitousKeyValueStore: UbiquitousKeyValueStore {

    // MARK: Types

    private typealias DataFormat = [String: [String : Any]]

    // MARK: Static Properties

    static let shared: UbiquitousKeyValueStore = StaticUbiquitousKeyValueStore()

    // MARK: Private Static Properties

    private static let userDefaults: UserDefaults! = UserDefaults(suiteName: StaticUbiquitousKeyValueStore.userDefaultsKey)
    private static let userDefaultsKey: String = "StaticUbiquitousKeyValueStore"

    // MARK: Private Properties

    private var data: DataFormat = [:]
    private let userDefaults: UserDefaults

    // MARK: Init

    private init(userDefaults: UserDefaults = StaticUbiquitousKeyValueStore.userDefaults) {
        self.userDefaults = userDefaults
        data = userDefaults.dictionary(forKey: StaticUbiquitousKeyValueStore.userDefaultsKey) as? DataFormat ?? [:]
    }

    func set(_ aDictionary: [String : Any]?, forKey aKey: String) {
        data[aKey] = aDictionary
    }

    func dictionary(forKey aKey: String) -> [String : Any]? {
        return data
    }

    func synchronize() -> Bool {
        userDefaults.set(data, forKey: StaticUbiquitousKeyValueStore.userDefaultsKey)
        return true
    }
}
