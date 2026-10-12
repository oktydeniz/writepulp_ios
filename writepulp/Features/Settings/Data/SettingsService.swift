//
//  SettingsService.swift
//  writepulp
//

import Foundation

@MainActor
final class SettingsService {
    private let api: APIClient
    private let session: SessionStore

    nonisolated init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    var currentRole: String? { session.role }
    /// Apple/Google-only accounts confirm deletion without a password.
    var hasPassword: Bool { session.hasPassword }

    func settings() async throws -> UserSettings {
        try await api.send(SettingsAPI.settings())
    }

    func save(_ settings: UserSettings) async throws {
        _ = try await api.send(SettingsAPI.update(settings))
    }

    func updateEmail(_ email: String) async throws {
        _ = try await api.send(SettingsAPI.updateEmail(email))
    }

    func sendVerificationCode(to email: String) async throws {
        _ = try await api.send(AuthAPI.resendCode(.init(email: email, type: .emailConfirm)))
    }

    func confirmEmail(_ email: String, code: String) async throws {
        _ = try await api.send(AuthAPI.confirmEmail(.init(email: email, code: code, type: .emailConfirm)))
    }

    /// `old` is nil when setting the first password of an Apple/Google account.
    func changePassword(old: String?, new: String, confirmation: String) async throws {
        _ = try await api.send(SettingsAPI.changePassword(.init(oldPassword: old, newPassword: new, newPasswordVerify: confirmation)))
        session.setHasPassword(true)
    }

    /// Keeps the cached flag in line with what the backend reports in settings.
    func syncHasPassword(_ hasPassword: Bool) {
        session.setHasPassword(hasPassword)
    }

    func switchRoleToAuthor() async throws {
        _ = try await api.send(SettingsAPI.switchRoleToAuthor())
        session.updateUserRole("AUTHOR")
    }

    /// Deleting signs the user out; the app then returns to login.
    func deleteAccount(password: String) async throws {
        _ = try await api.send(SettingsAPI.deleteAccount(password: password))
        session.logout()
    }

    func categoryGroups() async throws -> [CategoryGroup] {
        try await api.send(CategoryAPI.grouped())
    }
}
