//
//  SessionStore.swift
//  writepulp
//

import Foundation
import Observation

struct UserDisplayInfo: Equatable {
    let name: String
    let handle: String
    let avatar: String
}

/// Auth state: tokens live in the Keychain, everything else in UserDefaults.
@Observable
final class SessionStore {
    private enum Key {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userId = "user_id"
        static let email = "email"
        static let handle = "user_handle"
        static let fullName = "user_full_name"
        static let role = "user_role"
        static let avatar = "user_avatar"
        static let isLoggedIn = "is_logged_in"
        static let isLoggedInAsGuest = "is_logged_in_guest"
        static let deviceToken = "device_token"
        /// Keychain survives app deletion; this flag doesn't, so its absence means a fresh install.
        static let keychainInitialized = "keychain_initialized"
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var userId: String?
    private(set) var email: String?
    private(set) var handle: String?
    private(set) var fullName: String?
    private(set) var role: String?
    private(set) var avatar: String?
    private(set) var isLoggedIn = false
    private(set) var isLoggedInAsGuest = false
    private(set) var deviceToken: String?
    /// Set when the API could not refresh the token; the UI shows a notice and goes to login.
    private(set) var didSessionExpire = false

    init(defaults: UserDefaults, keychain: KeychainStore) {
        self.defaults = defaults
        self.keychain = keychain
        if !defaults.bool(forKey: Key.keychainInitialized) {
            keychain.removeAll()
            defaults.set(true, forKey: Key.keychainInitialized)
        }
        reload()
    }

    func reload() {
        accessToken = keychain.string(for: Key.accessToken)
        refreshToken = keychain.string(for: Key.refreshToken)
        userId = defaults.string(forKey: Key.userId)
        email = defaults.string(forKey: Key.email)
        handle = defaults.string(forKey: Key.handle)
        fullName = defaults.string(forKey: Key.fullName)
        role = defaults.string(forKey: Key.role)
        avatar = defaults.string(forKey: Key.avatar)
        isLoggedIn = defaults.bool(forKey: Key.isLoggedIn)
        isLoggedInAsGuest = defaults.bool(forKey: Key.isLoggedInAsGuest)
        deviceToken = defaults.string(forKey: Key.deviceToken)
    }

    // MARK: - Read

    var authData: LoginData? {
        guard let accessToken, let userId else { return nil }
        return LoginData(
            accessToken: accessToken,
            refreshToken: refreshToken ?? "",
            user: UserDto(
                id: userId,
                email: email ?? "",
                handle: handle ?? "",
                fullName: fullName ?? "",
                avatarImg: avatar,
                role: role ?? ""
            )
        )
    }

    var displayInfo: UserDisplayInfo {
        UserDisplayInfo(
            name: fullName ?? String(localized: "guest_name"),
            handle: "@\(handle ?? String(localized: "unknown_handle"))",
            avatar: avatar ?? ""
        )
    }

    // MARK: - Write

    func saveAuthData(_ data: LoginData) {
        saveAccessToken(data.accessToken)
        saveRefreshToken(data.refreshToken)
        set(data.user.id, Key.userId, \.userId)
        set(data.user.handle, Key.handle, \.handle)
        set(data.user.fullName, Key.fullName, \.fullName)
        set(data.user.email, Key.email, \.email)
        set(data.user.avatarImg ?? "", Key.avatar, \.avatar)
        set(data.user.role, Key.role, \.role)
        set(true, Key.isLoggedIn, \.isLoggedIn)
        set(false, Key.isLoggedInAsGuest, \.isLoggedInAsGuest)
    }

    func updateUserInfo(fullName: String, handle: String, email: String, avatar: String?) {
        set(fullName, Key.fullName, \.fullName)
        set(handle, Key.handle, \.handle)
        set(email, Key.email, \.email)
        set(avatar ?? "", Key.avatar, \.avatar)
    }

    func updateUserRole(_ role: String) {
        set(role, Key.role, \.role)
    }

    func saveAccessToken(_ token: String) {
        keychain.set(token, for: Key.accessToken)
        accessToken = token
    }

    func saveRefreshToken(_ token: String) {
        keychain.set(token, for: Key.refreshToken)
        refreshToken = token
    }

    func saveDeviceToken(_ token: String) {
        set(token, Key.deviceToken, \.deviceToken)
    }

    func setContinueAsGuest(_ value: Bool) {
        set(value, Key.isLoggedInAsGuest, \.isLoggedInAsGuest)
    }

    /// Email and role are intentionally kept.
    func logout() {
        keychain.set(nil, for: Key.accessToken)
        keychain.set(nil, for: Key.refreshToken)
        accessToken = nil
        refreshToken = nil
        set(nil, Key.userId, \.userId)
        set(nil, Key.handle, \.handle)
        set(nil, Key.fullName, \.fullName)
        set(nil, Key.avatar, \.avatar)
        set(nil, Key.deviceToken, \.deviceToken)
        set(false, Key.isLoggedIn, \.isLoggedIn)
        set(false, Key.isLoggedInAsGuest, \.isLoggedInAsGuest)
    }

    func acknowledgeSessionExpired() {
        didSessionExpire = false
    }

    // MARK: - Helpers

    private func set(_ value: String?, _ key: String, _ property: ReferenceWritableKeyPath<SessionStore, String?>) {
        defaults.set(value, forKey: key)
        self[keyPath: property] = value
    }

    private func set(_ value: Bool, _ key: String, _ property: ReferenceWritableKeyPath<SessionStore, Bool>) {
        defaults.set(value, forKey: key)
        self[keyPath: property] = value
    }
}

extension SessionStore: AuthTokenStore {
    func updateTokens(accessToken: String, refreshToken: String) {
        saveAccessToken(accessToken)
        saveRefreshToken(refreshToken)
    }

    func expireSession() {
        logout()
        didSessionExpire = true
    }
}
