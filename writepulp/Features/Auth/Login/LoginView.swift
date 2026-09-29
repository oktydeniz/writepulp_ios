//
//  LoginView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct LoginView: View {
    let onSignedIn: () -> Void
    let onContinueAsGuest: () -> Void
    let onSignUp: () -> Void
    let onForgotPassword: (_ email: String) -> Void
    let onEmailNotVerified: (_ email: String) -> Void

    private enum Field { case identifier, password }

    @State private var model: LoginViewModel
    @FocusState private var focusedField: Field?

    init(
        authService: AuthService,
        onSignedIn: @escaping () -> Void,
        onContinueAsGuest: @escaping () -> Void,
        onSignUp: @escaping () -> Void,
        onForgotPassword: @escaping (_ email: String) -> Void,
        onEmailNotVerified: @escaping (_ email: String) -> Void
    ) {
        self.onSignedIn = onSignedIn
        self.onContinueAsGuest = onContinueAsGuest
        self.onSignUp = onSignUp
        self.onForgotPassword = onForgotPassword
        self.onEmailNotVerified = onEmailNotVerified
        _model = State(initialValue: LoginViewModel(authService: authService))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Image("WritePulpLogo")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    Spacer().frame(height: 10)
                    Text("welcome_to_writepulp")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                    Spacer().frame(height: 5)
                    Text("sign_in_to_continue_your_reading_journey")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.onSurface)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 25)
                    form
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .dismissesKeyboardOnTap($focusedField)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .loadingOverlay(model.isLoading)
        .onChange(of: model.identifier) { model.clearError() }
        .onChange(of: model.password) { model.clearError() }
    }

    private var form: some View {
        VStack(spacing: 0) {
            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
            }

            AuthTextField(
                label: "email_or_handle",
                placeholder: String(localized: "login_identifier_placeholder"),
                text: $model.identifier,
                focus: $focusedField,
                field: .identifier,
                systemImage: "person.fill",
                contentType: .username,
                keyboard: .emailAddress,
                onSubmit: { focusedField = .password }
            )
            Spacer().frame(height: 20)
            AuthTextField(
                label: "password",
                placeholder: "••••••••",
                text: $model.password,
                focus: $focusedField,
                field: .password,
                systemImage: "lock.fill",
                isSecure: true,
                contentType: .password,
                submitLabel: .go,
                onSubmit: { signIn() }
            )
            Spacer().frame(height: 10)

            HStack {
                Toggle("remember_me", isOn: $model.rememberMe)
                    .toggleStyle(.writePulpCheckbox)
                Spacer()
                TextLinkButton(title: "forgot_password") {
                    onForgotPassword(model.emailForPasswordReset)
                }
            }
            Spacer().frame(height: 16)

            PrimaryButton(title: "sign_in") { signIn() }

            Spacer().frame(height: 8)
            TextLinkButton(title: "don_t_have_an_account", action: onSignUp)
            TextLinkButton(title: "continue_as_guest", action: onContinueAsGuest)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .background(AppColors.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColors.onSecondaryContainer.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, 20)
    }

    private func signIn() {
        focusedField = nil
        Task {
            switch await model.signIn() {
            case .signedIn: onSignedIn()
            case .emailNotVerified(let email): onEmailNotVerified(email)
            case nil: break
            }
        }
    }
}
