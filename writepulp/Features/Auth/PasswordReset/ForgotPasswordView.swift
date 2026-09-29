//
//  ForgotPasswordView.swift
//  writepulp
//

import SwiftUI

@MainActor
@Observable
final class ForgotPasswordViewModel {
    var email: String
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: AuthService

    init(email: String, authService: AuthService) {
        self.email = email
        self.authService = authService
    }

    /// Email the code was sent to, or nil on failure.
    func sendCode() async -> String? {
        if let error = FormValidator.email(email) {
            errorMessage = error
            return nil
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            return try await authService.requestPasswordReset(email: email)
        } catch APIError.cancelled {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

@MainActor
struct ForgotPasswordView: View {
    let onCodeSent: (_ email: String) -> Void

    private enum Field { case email }

    @State private var model: ForgotPasswordViewModel
    @FocusState private var focusedField: Field?

    init(email: String, authService: AuthService, onCodeSent: @escaping (_ email: String) -> Void) {
        self.onCodeSent = onCodeSent
        _model = State(initialValue: ForgotPasswordViewModel(email: email, authService: authService))
    }

    var body: some View {
        AuthFormScreen(focus: $focusedField) {
            Text("enter_your_email_address_to_receive_a_verification_code")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 10)
            AuthErrorText(message: model.errorMessage)
            Spacer().frame(height: 20)
            AuthTextField(
                label: "email",
                placeholder: String(localized: "your_email_com"),
                text: $model.email,
                focus: $focusedField,
                field: .email,
                systemImage: "envelope.fill",
                contentType: .emailAddress,
                keyboard: .emailAddress,
                submitLabel: .send,
                onSubmit: { sendCode() }
            )
            Spacer().frame(height: 20)
            PrimaryButton(title: "send_code") { sendCode() }
        }
        .loadingOverlay(model.isLoading)
        .onChange(of: model.email) { model.clearError() }
    }

    private func sendCode() {
        focusedField = nil
        Task {
            if let email = await model.sendCode() { onCodeSent(email) }
        }
    }
}
