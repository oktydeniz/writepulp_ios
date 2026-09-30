//
//  SettingsViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Edits a draft copy of the settings; "Save" sends the whole draft, "Discard" restores the last saved one.
/// Email, password, role and account deletion have their own endpoints and apply immediately.
@MainActor
@Observable
final class SettingsViewModel {
    enum Tab: CaseIterable, Hashable {
        case account, preferences, notifications, privacy
    }

    static let maxVerificationSends = 2

    var tab: Tab = .account
    private(set) var original: UserSettings?
    var draft: UserSettings?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    // Email verification
    private(set) var isCodeSent = false
    var verificationCode = ""
    private(set) var sendCount = 0
    private(set) var isEmailBusy = false

    // Password
    var isChangingPassword = false
    var oldPassword = ""
    var newPassword = ""
    var newPasswordConfirmation = ""
    private(set) var isSavingPassword = false

    // Role
    private(set) var role: String?
    private(set) var isUpgradingRole = false

    // Account deletion
    var isConfirmingDelete = false
    var deletePassword = ""
    private(set) var isDeleting = false

    // Categories
    var isPickingCategories = false
    private(set) var categoryGroups: [CategoryGroup] = []
    private(set) var isLoadingCategories = false

    private let service: SettingsService
    private let preferences: AppPreferences

    init(service: SettingsService, preferences: AppPreferences) {
        self.service = service
        self.preferences = preferences
        role = service.currentRole
    }

    var isDirty: Bool {
        guard let original, var draft else { return false }
        // Email is saved through its own flow, not "Save changes".
        draft.email = original.email
        draft.isMailVerified = original.isMailVerified
        return draft != original
    }

    var isEmailChanged: Bool { draft?.email != original?.email }
    var isEmailVerified: Bool { draft?.isMailVerified == true && !isEmailChanged }
    /// An unknown role (sessions saved before roles were stored) still gets the upgrade option.
    var isAuthorOrHigher: Bool { role.map { !$0.isEmpty && $0 != "READER" } ?? false }
    var canSendCode: Bool { !isEmailBusy && sendCount < Self.maxVerificationSends }

    var isInspirationBoxEnabled: Bool {
        get { preferences.isInspirationBoxEnabled }
        set { preferences.setInspirationBoxEnabled(newValue) }
    }

    // MARK: - Load / save

    func load() async {
        isLoading = original == nil
        defer { isLoading = false }
        do {
            let settings = try await service.settings()
            original = settings
            draft = settings
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard var draft, let original else { return }
        draft.email = original.email
        draft.isMailVerified = original.isMailVerified
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.save(draft)
            self.original = draft
            toastMessage = String(localized: "settings_save_success")
        } catch {
            show(error)
        }
    }

    func discard() {
        guard let original else { return }
        let email = draft?.email
        draft = original
        if let email { draft?.email = email }
    }

    // MARK: - Email

    func emailChanged() {
        isCodeSent = false
        verificationCode = ""
    }

    /// The backend sends the code itself when the email changes.
    func saveEmail() async {
        guard let email = draft?.email.trimmingCharacters(in: .whitespaces), !email.isEmpty else { return }
        if let error = FormValidator.email(email) {
            toastMessage = error
            return
        }
        isEmailBusy = true
        defer { isEmailBusy = false }
        do {
            try await service.updateEmail(email)
            original?.email = email
            original?.isMailVerified = false
            if draft?.email != email { draft?.email = email }
            draft?.isMailVerified = false
            isCodeSent = true
            sendCount = 1
            toastMessage = String(localized: "settings_code_sent")
        } catch {
            show(error)
        }
    }

    func sendCode() async {
        guard canSendCode, let email = draft?.email else { return }
        isEmailBusy = true
        defer { isEmailBusy = false }
        do {
            try await service.sendVerificationCode(to: email)
            isCodeSent = true
            verificationCode = ""
            sendCount += 1
            toastMessage = String(localized: "settings_code_sent")
        } catch {
            show(error)
        }
    }

    func confirmCode() async {
        let code = verificationCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, let email = draft?.email else { return }
        isEmailBusy = true
        defer { isEmailBusy = false }
        do {
            try await service.confirmEmail(email, code: code)
            original?.isMailVerified = true
            draft?.isMailVerified = true
            isCodeSent = false
            toastMessage = String(localized: "settings_email_verified")
        } catch {
            show(error)
        }
    }

    // MARK: - Password

    func changePassword() async {
        if let error = FormValidator.firstError(
            oldPassword.isEmpty || newPassword.isEmpty ? String(localized: "error_empty_fields") : nil,
            FormValidator.password(newPassword),
            FormValidator.passwordsMatch(newPassword, newPasswordConfirmation)
        ) {
            toastMessage = error
            return
        }
        isSavingPassword = true
        defer { isSavingPassword = false }
        do {
            try await service.changePassword(old: oldPassword, new: newPassword, confirmation: newPasswordConfirmation)
            oldPassword = ""
            newPassword = ""
            newPasswordConfirmation = ""
            isChangingPassword = false
            toastMessage = String(localized: "settings_password_changed")
        } catch {
            show(error)
        }
    }

    // MARK: - Role

    func upgradeToAuthor() async {
        guard !isUpgradingRole, !isAuthorOrHigher else { return }
        isUpgradingRole = true
        defer { isUpgradingRole = false }
        do {
            try await service.switchRoleToAuthor()
            role = "AUTHOR"
            toastMessage = String(localized: "settings_role_upgraded")
        } catch {
            show(error)
        }
    }

    // MARK: - Delete account

    func deleteAccount() async {
        guard !deletePassword.isEmpty else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await service.deleteAccount(password: deletePassword)
            deletePassword = ""
        } catch {
            show(error)
        }
    }

    // MARK: - Categories

    func openCategoryPicker() async {
        isPickingCategories = true
        guard categoryGroups.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categoryGroups = try await service.categoryGroups()
        } catch {
            show(error)
        }
    }

    func toggleCategory(_ id: String) {
        guard var selected = draft?.categoryPreferences else { return }
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count >= UserSettings.maxCategories {
            toastMessage = "settings_category_limit_reached".localized(UserSettings.maxCategories)
            return
        } else {
            selected.insert(id)
        }
        draft?.categoryPreferences = selected
    }

    private func show(_ error: Error) {
        if case APIError.cancelled = error { return }
        toastMessage = error.localizedDescription
    }
}
