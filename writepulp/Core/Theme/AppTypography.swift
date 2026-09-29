//
//  AppTypography.swift
//  writepulp
import SwiftUI

enum AppTextStyle {

    case bodyLarge

    var font: Font {
        switch self {
        case .bodyLarge: .system(size: 16, weight: .regular)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .bodyLarge: 24 - UIFont.systemFont(ofSize: 16).lineHeight
        }
    }

    var tracking: CGFloat {
        switch self {
        case .bodyLarge: 0.5
        }
    }
}

extension View {
    func appTextStyle(_ style: AppTextStyle) -> some View {
        font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}
