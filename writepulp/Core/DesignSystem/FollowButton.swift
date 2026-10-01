//
//  FollowButton.swift
//  writepulp
//

import SwiftUI

/// Compact pill for follow / accept actions. Active states (following, requested) use the muted style.
struct FollowButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isActive = false
    var height: CGFloat = 36
    var cornerRadius: CGFloat = 18
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? AppColors.primary : AppColors.onPrimary)
            .padding(.horizontal, 16)
            .frame(height: height)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(
                isActive ? AppColors.primary.opacity(0.14) : AppColors.primary,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
