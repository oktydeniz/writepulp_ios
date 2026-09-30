//
//  FilterChip.swift
//  writepulp
//

import SwiftUI

struct FilterChip: View {
    let title: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            title
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? AppColors.onPrimary : AppColors.onSurface)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primary : AppColors.surface, in: Capsule())
                .overlay { Capsule().stroke(isSelected ? Color.clear : AppColors.outline) }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
