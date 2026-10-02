//
//  ReaderChrome.swift
//  writepulp
//

import SwiftUI

/// Reading-theme navigation bar and background, no tab bar, and the coin session paused
/// whenever the reader isn't visible (another screen on top, app in background).
private struct ReaderChrome: ViewModifier {
    let theme: ReaderTheme
    let pause: () -> Void
    let resume: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
            .background(theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.isDark ? .dark : .light, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .tint(theme.text)
            .onAppear(perform: resume)
            .onDisappear(perform: pause)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resume() } else { pause() }
            }
    }
}

extension View {
    func readerChrome(theme: ReaderTheme, pause: @escaping () -> Void, resume: @escaping () -> Void) -> some View {
        modifier(ReaderChrome(theme: theme, pause: pause, resume: resume))
    }
}

struct ReaderToolbarIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }
}

/// Thin bar showing how far the page has been read.
struct ReaderProgressLine: View {
    let state: ReaderScrollState
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(AppColors.primary)
                .frame(width: proxy.size.width * state.fraction)
        }
        .frame(height: 2)
        .background(track)
        .accessibilityHidden(true)
    }
}
