//
//  SignUpView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct SignUpView: View {
    let onRegistered: (_ email: String) -> Void
    let onSignIn: () -> Void

    private enum Field { case fullName, email, handle, password, confirmation }

    @State private var model: SignUpViewModel
    @FocusState private var focusedField: Field?

    init(
        authService: AuthService,
        onRegistered: @escaping (_ email: String) -> Void,
        onSignIn: @escaping () -> Void
    ) {
        self.onRegistered = onRegistered
        self.onSignIn = onSignIn
        _model = State(initialValue: SignUpViewModel(authService: authService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("WritePulpLogo")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Spacer().frame(height: 8)
                Text("create_account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                Spacer().frame(height: 15)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.error)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 15)
                }

                VStack(spacing: 15) {
                    AuthTextField(
                        label: "full_name",
                        placeholder: String(localized: "full_name"),
                        text: $model.fullName,
                        focus: $focusedField,
                        field: .fullName,
                        systemImage: "person.fill",
                        contentType: .name,
                        onSubmit: { focusedField = .email }
                    )
                    AuthTextField(
                        label: "email",
                        placeholder: String(localized: "your_email_com"),
                        text: $model.email,
                        focus: $focusedField,
                        field: .email,
                        systemImage: "envelope.fill",
                        contentType: .emailAddress,
                        keyboard: .emailAddress,
                        onSubmit: { focusedField = .handle }
                    )
                    AuthTextField(
                        label: "handle",
                        placeholder: String(localized: "handle"),
                        text: $model.handle,
                        focus: $focusedField,
                        field: .handle,
                        systemImage: "at",
                        contentType: .username,
                        onSubmit: { focusedField = .password }
                    )
                    AuthTextField(
                        label: "password",
                        placeholder: "••••••••",
                        text: $model.password,
                        focus: $focusedField,
                        field: .password,
                        systemImage: "lock.fill",
                        isSecure: true,
                        contentType: .newPassword,
                        onSubmit: { focusedField = .confirmation }
                    )
                    AuthTextField(
                        label: "confirm_password",
                        placeholder: "••••••••",
                        text: $model.passwordConfirmation,
                        focus: $focusedField,
                        field: .confirmation,
                        systemImage: "lock.fill",
                        isSecure: true,
                        contentType: .newPassword,
                        submitLabel: .done,
                        onSubmit: { focusedField = nil }
                    )
                    DateField(
                        label: "birthday",
                        date: $model.birthDate,
                        range: model.birthDateRange,
                        initialDate: model.birthDateInitial
                    )
                }

                TermsAgreement(isAccepted: $model.acceptsTerms)
                    .padding(.vertical, 12)

                PrimaryButton(title: "create_account") {
                    focusedField = nil
                    Task {
                        if let email = await model.register() { onRegistered(email) }
                    }
                }
                Spacer().frame(height: 12)
                Button(action: onSignIn) {
                    Text(signInText).font(.system(size: 14))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(24)
            .dismissesKeyboardOnTap($focusedField)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onSignIn) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel(Text("back"))
            }
        }
        .loadingOverlay(model.isLoading)
        .onChange(of: model.email) { model.clearError() }
        .onChange(of: model.password) { model.clearError() }
    }

    private var signInText: AttributedString {
        var prompt = AttributedString(String(localized: "already_have_an_account"))
        prompt.foregroundColor = AppColors.onSurface
        var action = AttributedString(String(localized: "sign_in"))
        action.foregroundColor = AppPalette.primaryColor
        action.font = .system(size: 14, weight: .bold)
        return prompt + action
    }
}

/// Checkbox + "I accept the Terms of Service and Privacy Policy" with both as links.
private struct TermsAgreement: View {
    @Binding var isAccepted: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                isAccepted.toggle()
            } label: {
                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isAccepted ? AppColors.onSurface : AppPalette.appLightGray)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isAccepted ? .isSelected : [])

            Text(agreementText)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurface)
                .tint(AppPalette.primaryColor)
            Spacer(minLength: 0)
        }
    }

    private var agreementText: AttributedString {
        let terms = String(localized: "terms_of_service")
        let privacy = String(localized: "privacy_policy")
        var text = AttributedString(String(format: String(localized: "terms_and_privacy_full_text"), terms, privacy))
        for (label, url) in [(terms, AppLinks.termsOfService), (privacy, AppLinks.privacyPolicy)] {
            if let range = text.range(of: label) {
                text[range].link = url
                text[range].font = .system(size: 12, weight: .bold)
                text[range].underlineStyle = .single
            }
        }
        return text
    }
}
