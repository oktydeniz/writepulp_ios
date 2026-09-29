//
//  AppTheme.swift
//  writepulp
//
import SwiftUI

private struct WritePulpThemeModifier: ViewModifier {
    let preferences: AppPreferences

    func body(content: Content) -> some View {
        content
            .tint(AppColors.primary)
            .foregroundStyle(AppColors.onBackground)
            .preferredColorScheme(preferences.colorScheme)
    }
}

extension View {
    func writePulpTheme(_ preferences: AppPreferences) -> some View {
        modifier(WritePulpThemeModifier(preferences: preferences))
    }

    /// Makes the stores available via @Environment(SessionStore.self) etc.
    func localStorage(_ storage: LocalStorage) -> some View {
        environment(storage.session)
            .environment(storage.app)
            .environment(storage.reader)
    }
}
