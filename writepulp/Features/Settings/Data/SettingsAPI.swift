//
//  SettingsAPI.swift
//  writepulp
//

import Foundation

enum SettingsAPI {
    struct SingleValue: Encodable { let value: String }

    struct ChangePasswordRequest: Encodable {
        let oldPassword: String
        let newPassword: String
        let newPasswordVerify: String
    }

    static func settings() -> Endpoint<UserSettings> {
        Endpoint(path: "settings")
    }

    static func update(_ settings: UserSettings) -> Endpoint<EmptyResponse> {
        Endpoint(path: "settings", method: .put, body: UserSettingsUpdate(settings: settings))
    }

    /// The backend marks the new address unverified and mails it a code.
    static func updateEmail(_ email: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "settings/e-mail", method: .put, body: SingleValue(value: email))
    }

    static func changePassword(_ request: ChangePasswordRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/change-password", method: .put, body: request)
    }

    static func switchRoleToAuthor() -> Endpoint<EmptyResponse> {
        Endpoint(path: "profile/role/author", method: .post)
    }

    static func deleteAccount(password: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "profile", method: .delete, body: SingleValue(value: password))
    }
}
