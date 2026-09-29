//
//  ResetPasswordView.swift
//  writepulp
//

import SwiftUI

@MainActor
@Observable
final class ResetPasswordViewModel {
    var password = ""
    var confirmation = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let email: String
    private let code: String
    private let authService: AuthService

    init(email: String, code: String, authService: AuthService) {
        self.email = email
        self.code = code
        self.authService = authService
    }

    var showsMismatch: Bool { !confirmation.isEmpty && password != confirmation }

    func reset() async -> Bool {
        let error: String? = if password.isEmpty || confirmation.isEmpty {
            String(localized: "error_empty_fields")
        } else {
            FormValidator.firstError(
                FormValidator.password(password),
                FormValidator.passwordsMatch(password, confirmation)
            )
        }
        if let error {
            errorMessage = error
            return false
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.resetPassword(email: email, code: code, newPassword: password, confirmation: confirmation)
            return true
        } catch APIError.cancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

@MainActor
struct ResetPasswordView: View {
    let onReset: () -> Void

    private enum Field { case password, confirmation }

    @State private var model: ResetPasswordViewModel
    @FocusState private var focusedField: Field?

    init(email: String, code: String, authService: AuthService, onReset: @escaping () -> Void) {
        self.onReset = onReset
        _model = State(initialValue: ResetPasswordViewModel(email: email, code: code, authService: authService))
    }

    var body: some View {
        AuthFormScreen(focus: $focusedField) {
            Text("new_password")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
            Text("please_enter_your_nee_psw")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            AuthErrorText(message: model.errorMessage)
                .padding(.top, 8)
            Spacer().frame(height: 15)

            AuthTextField(
                label: "new_password",
                placeholder: "••••••••",
                text: $model.password,
                focus: $focusedField,
                field: .password,
                systemImage: "lock.fill",
                isSecure: true,
                contentType: .newPassword,
                onSubmit: { focusedField = .confirmation }
            )
            Spacer().frame(height: 16)
            AuthTextField(
                label: "confirm_new_password",
                placeholder: "••••••••",
                text: $model.confirmation,
                focus: $focusedField,
                field: .confirmation,
                systemImage: "lock.fill",
                isSecure: true,
                isError: model.showsMismatch,
                contentType: .newPassword,
                submitLabel: .done,
                onSubmit: { focusedField = nil }
            )
            if model.showsMismatch {
                Text("passwords_do_not_match")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            Spacer().frame(height: 32)
            PrimaryButton(title: "reset_password") {
                focusedField = nil
                Task {
                    if await model.reset() { onReset() }
                }
            }
        }
        .loadingOverlay(model.isLoading)
        .onChange(of: model.password) { model.clearError() }
        .onChange(of: model.confirmation) { model.clearError() }
    }
}
