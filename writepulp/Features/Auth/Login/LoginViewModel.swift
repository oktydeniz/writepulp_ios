//
//  LoginViewModel.swift
//  writepulp
//

import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var identifier: String
    var password = ""
    var rememberMe: Bool
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        let remembered = authService.rememberedIdentifier ?? ""
        self.authService = authService
        identifier = remembered
        rememberMe = !remembered.isEmpty
    }

    /// Prefill for "forgot password" only when what was typed is an email.
    var emailForPasswordReset: String {
        let value = identifier.trimmingCharacters(in: .whitespaces)
        return FormValidator.email(value) == nil ? value : ""
    }

    /// nil when validation or the request failed (the error is shown on screen).
    func signIn() async -> AuthService.LoginResult? {
        if let error = FormValidator.firstError(
            FormValidator.loginIdentifier(identifier),
            FormValidator.password(password)
        ) {
            errorMessage = error
            return nil
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            return try await authService.login(identifier: identifier, password: password, rememberMe: rememberMe)
        } catch APIError.cancelled {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        authService.prepareAppleRequest(request)
    }

    /// true once signed in; a cancelled sheet or a failure (shown on screen) returns false.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async -> Bool {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = String(localized: "err_apple_sign_in")
            }
            return false
        case .success(let authorization):
            isLoading = true
            defer { isLoading = false }
            do {
                try await authService.signInWithApple(authorization)
                return true
            } catch APIError.cancelled {
                return false
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
