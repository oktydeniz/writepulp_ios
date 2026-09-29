//
//  AuthSuccessView.swift
//  writepulp
//

import SwiftUI

/// Shown after a code was verified (registration, password reset, or verify-on-login).
struct AuthSuccessView: View {
    let purpose: VerifyPurpose
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 100, height: 100)
                .background(AppPalette.primaryColor, in: Circle())
            Spacer().frame(height: 32)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
            Text(description)
                .appTextStyle(.bodyLarge)
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 48)
            PrimaryButton(title: purpose == .login ? "sign_in" : "start_the_app", action: onContinue)
            Spacer()
        }
        .padding(24)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled()
    }

    private var title: LocalizedStringKey {
        switch purpose {
        case .registration: "registration_done"
        case .passwordReset: "password_reset"
        case .login: "email_verified_title"
        }
    }

    private var description: LocalizedStringKey {
        switch purpose {
        case .registration: "your_account_has_been_successfully"
        case .passwordReset: "your_password_has_been_successfully"
        case .login: "email_verified_sign_in_desc"
        }
    }
}
