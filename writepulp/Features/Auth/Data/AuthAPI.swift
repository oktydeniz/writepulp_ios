//
//  AuthAPI.swift
//  writepulp
//

import Foundation

/// Backend `VerificationType`.
enum VerificationType: String, Encodable {
    case emailConfirm = "EMAIL_CONFIRM"
    case passwordReset = "PASSWORD_RESET"
}

enum AuthAPI {
    struct LoginRequest: Encodable {
        let identifier: String
        let password: String
    }

    struct ResendCodeRequest: Encodable {
        let email: String
        let type: VerificationType
    }

    struct ConfirmEmailRequest: Encodable {
        let email: String
        let code: String
        let type: VerificationType
    }

    struct LogoutRequest: Encodable {
        let refreshToken: String?
    }

    struct RegisterRequest: Encodable {
        let email: String
        let handle: String
        let password: String
        let passwordVerify: String
        let fullName: String
        /// yyyy-MM-dd
        let birthDate: String
        let lang: String
    }

    struct ForgotPasswordRequest: Encodable {
        let email: String
    }

    struct ResetPasswordRequest: Encodable {
        let email: String
        let code: String
        let newPassword: String
        let newPasswordVerify: String
    }

    /// `data` of a USER_NOT_VERIFIED (1405) login error.
    struct UnverifiedEmail: Decodable {
        let email: String
    }

    static func login(_ request: LoginRequest) -> Endpoint<LoginData> {
        Endpoint(path: "auth/login", method: .post, body: request, requiresAuth: false)
    }

    static func resendCode(_ request: ResendCodeRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/resend-code", method: .post, body: request, requiresAuth: false)
    }

    static func confirmEmail(_ request: ConfirmEmailRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/confirm-email", method: .post, body: request, requiresAuth: false)
    }

    static func logout(_ request: LogoutRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/logout", method: .post, body: request)
    }

    static func register(_ request: RegisterRequest) -> Endpoint<LoginData> {
        Endpoint(path: "auth/register", method: .post, body: request, requiresAuth: false)
    }

    static func forgotPassword(_ request: ForgotPasswordRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/forgot-password", method: .post, body: request, requiresAuth: false)
    }

    static func resetPassword(_ request: ResetPasswordRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/reset-password", method: .post, body: request, requiresAuth: false)
    }
}
