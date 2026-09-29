//
//  LocalStorage.swift
//  writepulp
//

import Foundation

/// Single owner of all local stores; created once at app launch.
final class LocalStorage {
    let session: SessionStore
    let app: AppPreferences
    let reader: ReaderPreferences

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        session = SessionStore(defaults: defaults, keychain: keychain)
        app = AppPreferences(defaults: defaults)
        reader = ReaderPreferences(defaults: defaults)
    }

    /// Wipes everything (UserDefaults + Keychain), including onboarding and preferences.
    func clearAll() {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        keychain.removeAll()
        session.reload()
        app.reload()
        reader.reload()
    }
}
