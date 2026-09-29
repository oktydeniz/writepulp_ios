//
//  VerifyCodeView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct VerifyCodeView: View {
    /// Receives the verified code (password reset sends it along with the new password).
    let onVerified: (_ code: String) -> Void

    @State private var model: VerifyCodeViewModel

    init(email: String, purpose: VerifyPurpose, authService: AuthService, onVerified: @escaping (_ code: String) -> Void) {
        self.onVerified = onVerified
        _model = State(initialValue: VerifyCodeViewModel(email: email, purpose: purpose, authService: authService))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Text(model.purpose == .passwordReset ? "reset_password" : "verify_account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                    Text(String(format: String(localized: "please_enter_the_6_digit_code_sent_to"), model.email))
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurface)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.bottom, 32)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.error)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 16)
                    }

                    OTPField(code: $model.code, isError: model.errorMessage != nil)
                    Spacer().frame(height: 32)
                    resendFooter
                    Spacer().frame(height: 24)
                    PrimaryButton(title: "verify") {
                        Task {
                            if await model.verify() { onVerified(model.code) }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(model.isLoading)
        .onChange(of: model.code) { model.clearError() }
        .onDisappear { model.stopCountdown() }
    }

    @ViewBuilder
    private var resendFooter: some View {
        if model.isResendLimitReached {
            Text("resend_limit_reached")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.error.opacity(0.8))
                .multilineTextAlignment(.center)
        } else {
            let label = model.secondsUntilResend > 0
                ? String(format: "00:%02d", model.secondsUntilResend)
                : String(localized: "resend_code")
            Button {
                Task { await model.resend() }
            } label: {
                Text(resendText(label: label))
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.onSurface)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .disabled(!model.canResend)
        }
    }

    private func resendText(label: String) -> AttributedString {
        var text = AttributedString(String(format: String(localized: "didnt_receive_mail"), label))
        if let range = text.range(of: label) {
            text[range].font = .system(size: 14, weight: .bold)
            text[range].foregroundColor = model.canResend ? AppColors.primary : AppPalette.appLightGray
            if model.canResend { text[range].underlineStyle = .single }
        }
        return text
    }
}
