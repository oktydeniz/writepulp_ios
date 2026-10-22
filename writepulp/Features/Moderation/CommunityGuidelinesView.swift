//
//  CommunityGuidelinesView.swift
//  writepulp
//

import SwiftUI

/// Shown once per Terms version to signed-in users who haven't accepted it yet (Apple/Google
/// sign-ups, existing accounts after an update). There's no way past it other than accepting
/// or signing out: the rules have to be agreed to before anyone can post or interact.
struct CommunityGuidelinesView: View {
    let version: String
    let onAccepted: () -> Void
    let onSignOut: () -> Void

    @Environment(\.moderation) private var moderation
    @Environment(\.openURL) private var openURL
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let rules: [(icon: String, text: LocalizedStringKey)] = [
        ("hand.raised", "guidelines_rule_respect"),
        ("exclamationmark.bubble", "guidelines_rule_hate"),
        ("eye.slash", "guidelines_rule_sexual"),
        ("figure.and.child.holdinghands", "guidelines_rule_children"),
        ("doc.on.doc", "guidelines_rule_copyright"),
        ("envelope.badge", "guidelines_rule_spam"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.primary)
                    Text("guidelines_title")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.onBackground)
                    Text("guidelines_intro")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.onBackground.opacity(0.8))

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(rules.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: rules[index].icon)
                                    .frame(width: 24)
                                    .foregroundStyle(AppColors.primary)
                                Text(rules[index].text)
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppColors.onBackground)
                            }
                        }
                    }

                    Text("guidelines_zero_tolerance")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.onBackground)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        openURL(AppLinks.termsOfService)
                    } label: {
                        Label("guidelines_read_terms", systemImage: "doc.text")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(24)
            }

            VStack(spacing: 10) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.error)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await accept() }
                } label: {
                    Group {
                        if isSaving { ProgressView().tint(.white) } else { Text("guidelines_accept") }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isSaving)

                Button("guidelines_sign_out", action: onSignOut)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.onBackground.opacity(0.7))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func accept() async {
        guard let moderation else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await moderation.acceptTerms(version: version)
            onAccepted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
