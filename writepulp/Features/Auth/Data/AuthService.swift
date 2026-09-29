//
//  AuthService.swift
//  writepulp
//

import Foundation

/// Why a verification code is being entered; decides the backend type and where success leads.
enum VerifyPurpose: Hashable {
    case registration
    case passwordReset
    /// Login was refused because the email isn't verified yet.
    case login

    var verificationType: VerificationType {
        self == .passwordReset ? .passwordReset : .emailConfirm
    }
}

/// Auth use cases: talks to the API and keeps the local session in sync.
@MainActor
final class AuthService {
    enum LoginResult {
        case signedIn
        /// Password was right but the email isn't verified; a fresh code has been sent to it.
        case emailNotVerified(email: String)
    }

    private let api: APIClient
    private let session: SessionStore
    private let preferences: AppPreferences

    /// Tokens from a fresh registration, saved only once the email is confirmed, so quitting
    /// on the verify screen doesn't leave an unverified account signed in.
    private var pendingRegistration: (email: String, data: LoginData)?

    nonisolated init(api: APIClient, session: SessionStore, preferences: AppPreferences) {
        self.api = api
        self.session = session
        self.preferences = preferences
    }

    var rememberedIdentifier: String? { preferences.rememberedEmail }

    // MARK: - Login

    func login(identifier: String, password: String, rememberMe: Bool) async throws -> LoginResult {
        let identifier = identifier.trimmingCharacters(in: .whitespaces)
        do {
            let data = try await api.send(AuthAPI.login(.init(identifier: identifier, password: password)))
            session.saveAuthData(data)
            if rememberMe {
                preferences.saveRememberedEmail(identifier)
            } else {
                preferences.clearRememberedEmail()
            }
            return .signedIn
        } catch let error as APIError where error.businessCode == BusinessCode.userNotVerified {
            guard let email = error.payload(AuthAPI.UnverifiedEmail.self)?.email else { throw error }
            // An earlier code may have expired; the verify screen can still resend.
            _ = try? await api.send(AuthAPI.resendCode(.init(email: email, type: .emailConfirm)))
            return .emailNotVerified(email: email)
        }
    }

    func continueAsGuest() {
        session.setContinueAsGuest(true)
    }

    /// Leaves guest mode so the app goes back to login.
    func exitGuestMode() {
        session.setContinueAsGuest(false)
    }

    // MARK: - Registration

    /// Creates the account; the backend mails a code. Returns the email to verify.
    func register(
        fullName: String,
        email: String,
        handle: String,
        password: String,
        passwordConfirmation: String,
        birthDate: Date
    ) async throws -> String {
        let email = Self.normalizedEmail(email)
        let request = AuthAPI.RegisterRequest(
            email: email,
            handle: handle,
            password: password,
            passwordVerify: passwordConfirmation,
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            birthDate: Self.birthDateFormatter.string(from: birthDate),
            lang: AppPreferences.currentLanguageCode
        )
        let data = try await api.send(AuthAPI.register(request))
        pendingRegistration = (email, data)
        return email
    }

    // MARK: - Codes

    func verifyCode(email: String, code: String, purpose: VerifyPurpose) async throws {
        _ = try await api.send(AuthAPI.confirmEmail(.init(email: email, code: code, type: purpose.verificationType)))
        if purpose == .registration, let pending = pendingRegistration, pending.email == email {
            session.saveAuthData(pending.data)
            pendingRegistration = nil
        }
    }

    func resendCode(email: String, purpose: VerifyPurpose) async throws {
        _ = try await api.send(AuthAPI.resendCode(.init(email: email, type: purpose.verificationType)))
    }

    // MARK: - Password reset

    /// Mails a reset code. Returns the email the code was sent to.
    func requestPasswordReset(email: String) async throws -> String {
        let email = Self.normalizedEmail(email)
        _ = try await api.send(AuthAPI.forgotPassword(.init(email: email)))
        return email
    }

    func resetPassword(email: String, code: String, newPassword: String, confirmation: String) async throws {
        let request = AuthAPI.ResetPasswordRequest(
            email: email,
            code: code,
            newPassword: newPassword,
            newPasswordVerify: confirmation
        )
        _ = try await api.send(AuthAPI.resetPassword(request))
    }

    // MARK: - Logout

    /// Revokes the tokens on the backend (best effort, capped) and always clears the local session.
    func logout() async {
        let request = AuthAPI.LogoutRequest(refreshToken: session.refreshToken)
        let api = api
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = try? await api.send(AuthAPI.logout(request)) }
            group.addTask { try? await Task.sleep(for: .seconds(4)) }
            await group.next()
            group.cancelAll()
        }
        session.logout()
    }

    // MARK: - Helpers

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
