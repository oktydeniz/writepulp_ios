//
//  AuthFlowView.swift
//  writepulp
//

import SwiftUI

/// Which screen the auth flow opens on. Login and sign-up replace each other rather than stack.
enum AuthStart {
    case login
    case signUp
}

enum AuthRoute: Hashable {
    case forgotPassword(email: String)
    case verify(email: String, purpose: VerifyPurpose)
    case resetPassword(email: String, code: String)
    case success(VerifyPurpose)
}

@MainActor
struct AuthFlowView: View {
    let authService: AuthService
    /// Signed in or continuing as guest: leave the auth flow.
    let onFinished: () -> Void

    @State private var root: AuthStart
    @State private var path: [AuthRoute] = []

    init(start: AuthStart, authService: AuthService, onFinished: @escaping () -> Void) {
        self.authService = authService
        self.onFinished = onFinished
        _root = State(initialValue: start)
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: AuthRoute.self) { destination($0) }
        }
        .tint(AppColors.onSurface)
    }

    @ViewBuilder
    private var rootView: some View {
        switch root {
        case .login:
            LoginView(
                authService: authService,
                onSignedIn: onFinished,
                onContinueAsGuest: {
                    authService.continueAsGuest()
                    onFinished()
                },
                onSignUp: { switchRoot(to: .signUp) },
                onForgotPassword: { email in path.append(.forgotPassword(email: email)) },
                onEmailNotVerified: { email in path.append(.verify(email: email, purpose: .login)) }
            )
        case .signUp:
            SignUpView(
                authService: authService,
                onRegistered: { email in path.append(.verify(email: email, purpose: .registration)) },
                onSignIn: { switchRoot(to: .login) }
            )
        }
    }

    @ViewBuilder
    private func destination(_ route: AuthRoute) -> some View {
        switch route {
        case .forgotPassword(let email):
            ForgotPasswordView(email: email, authService: authService) { sentTo in
                path.append(.verify(email: sentTo, purpose: .passwordReset))
            }
        case .verify(let email, let purpose):
            VerifyCodeView(email: email, purpose: purpose, authService: authService) { code in
                switch purpose {
                case .passwordReset:
                    path.append(.resetPassword(email: email, code: code))
                case .registration, .login:
                    // Replace the stack so "back" can't return to the used code.
                    path = [.success(purpose)]
                }
            }
        case .resetPassword(let email, let code):
            ResetPasswordView(email: email, code: code, authService: authService) {
                path = [.success(.passwordReset)]
            }
        case .success(let purpose):
            AuthSuccessView(purpose: purpose) {
                switch purpose {
                case .registration:
                    onFinished()
                case .passwordReset, .login:
                    path = []
                    root = .login
                }
            }
        }
    }

    private func switchRoot(to start: AuthStart) {
        path = []
        withAnimation(.easeInOut(duration: 0.2)) { root = start }
    }
}
