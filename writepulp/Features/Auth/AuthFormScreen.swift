//
//  AuthFormScreen.swift
//  writepulp
//

import SwiftUI

/// Shared layout for the pushed auth screens: content centered, scrollable when the keyboard is up.
struct AuthFormScreen<Field: Hashable, Content: View>: View {
    let focus: FocusState<Field?>.Binding
    let content: Content

    init(focus: FocusState<Field?>.Binding, @ViewBuilder content: () -> Content) {
        self.focus = focus
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    content
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .dismissesKeyboardOnTap(focus)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AuthErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.error)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}
