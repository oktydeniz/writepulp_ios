//
//  PlaceholderView.swift
//  writepulp
//

import SwiftUI

/// Stand-in for screens that aren't built yet.
struct PlaceholderView: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Image("WritePulpLogo")
                .resizable()
                .frame(width: 56, height: 56)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            Text("coming_soon")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
            if let actionTitle {
                TextLinkButton(title: actionTitle, color: AppColors.primary, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
    }
}
