//
//  EmptyStateView.swift
//  writepulp
//

import SwiftUI

/// Icon, title and optional message/action for empty lists.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var actionSystemImage = "plus"
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(AppColors.primary.opacity(0.6))
                .padding(.bottom, 4)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.onPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Error message with a retry link, for screens whose first load failed.
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.error)
                .multilineTextAlignment(.center)
            TextLinkButton(title: "retry", color: AppColors.primary, action: retry)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
