//
//  AppColors.swift
//  writepulp

import SwiftUI
import UIKit

enum AppPalette {
    static let primaryColor = Color(hex: 0x60809E)
    static let primaryDark = Color(hex: 0x4A6B88)
    static let primaryLight = Color(hex: 0x7A9BB8)
    static let appLightGray = Color(hex: 0x9CA3AF)
    static let appTextDarkBlue = Color(hex: 0x4B5563)
    static let appBorderGray = Color(hex: 0xE5E7EB)
    static let appTextDark = Color(hex: 0x111827)
    static let appRed = Color(hex: 0xEF4444)
    static let textColorBoldBlue = Color(hex: 0x1E293B)
    static let googleBtn = Color(hex: 0x334155)
    static let strokeColor = Color(hex: 0xE2E8F0)
    static let searchFieldBgColor = Color(hex: 0xF3F4F6)

    static let goldAccent = Color(hex: 0xE8B84B)
}

enum AppColors {
    static let primary = dynamic(light: 0x60809E, dark: 0x7A9BB8)
    static let onPrimary = dynamic(light: 0xFFFFFF, dark: 0x111827)
    static let primaryContainer = dynamic(light: 0x7A9BB8, dark: 0x4A6B88)
    static let secondary = dynamic(light: 0x9CA3AF, dark: 0x4B5563)
    static let onSecondary = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let secondaryContainer = dynamic(light: 0x60809E, dark: 0x7A9BB8, alpha: 0.7)
    static let onSecondaryContainer = dynamic(light: 0x60809E, dark: 0x7A9BB8)
    static let background = dynamic(light: 0xF5F8FB, dark: 0x111827)
    static let onBackground = dynamic(light: 0x111827, dark: 0xF9FAFB)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1F2937)
    static let onSurface = dynamic(light: 0x111827, dark: 0xE5E7EB)
    static let onSurfaceVariant = dynamic(light: 0x60809E, dark: 0x9CA3AF)
    static let surfaceContainer = dynamic(light: 0xFFFFFF, dark: 0x1F2937)
    static let error = dynamic(light: 0xEF4444, dark: 0xEF4444)
    static let outline = dynamic(light: 0xE5E7EB, dark: 0x938F99)
    static let skeleton = dynamic(light: 0xE5E9EF, dark: 0x2B3544)
    static let skeletonHighlight = dynamic(light: 0xF6F8FA, dark: 0x3B4657)

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: 0xF5F8FB), Color(hex: 0xF2F6FA)],
        startPoint: .top,
        endPoint: .bottom
    )

    private static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light, alpha: alpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
}
