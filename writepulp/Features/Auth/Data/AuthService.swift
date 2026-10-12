//
//  AuthService.swift
//  writepulp
//

import AuthenticationServices
import CryptoKit
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

enum AppleSignInError: LocalizedError {
    case invalidCredential

    var errorDescription: String? { String(localized: "err_apple_sign_in") }
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
    private var push: PushNotifications { .shared }

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
            Task { await push.registerToken() }
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

    // MARK: - Sign in with Apple

    /// Raw nonce of the Apple request in flight; its SHA-256 goes to Apple, the raw value to us.
    private var appleNonce: String?

    /// Configures the Apple request: name + email scopes and a fresh hashed nonce.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Signs in, or creates the account on first use. Apple accounts arrive verified, so the
    /// session is saved right away - there is no verify-code step.
    func signInWithApple(_ authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = appleNonce
        else { throw AppleSignInError.invalidCredential }
        appleNonce = nil

        let fullName = credential.fullName.flatMap {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }?.trimmingCharacters(in: .whitespaces)

        let request = AuthAPI.SocialLoginRequest(
            provider: "APPLE",
            idToken: idToken,
            nonce: nonce,
            fullName: fullName?.isEmpty == false ? fullName : nil,
            lang: AppPreferences.currentLanguageCode
        )
        let data = try await api.send(AuthAPI.socialLogin(request))
        session.saveAuthData(data)
        Task { await push.registerToken() }
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
            Task { await push.registerToken() }
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

    /// Unregisters this device's push token and revokes the tokens on the backend (best effort,
    /// capped), then always clears the local session. Both calls need the access token, so they
    /// run before the session is cleared.
    func logout() async {
        let request = AuthAPI.LogoutRequest(refreshToken: session.refreshToken)
        let api = api
        let push = push
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await push.unregisterToken()
                _ = try? await api.send(AuthAPI.logout(request))
            }
            group.addTask { try? await Task.sleep(for: .seconds(4)) }
            await group.next()
            group.cancelAll()
        }
        session.logout()
    }

    // MARK: - Helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

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
