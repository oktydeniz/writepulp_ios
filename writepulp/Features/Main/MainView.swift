//
//  MainView.swift
//  writepulp
//

import SwiftUI

/// Signed-in (or guest) shell: tab bar, per-tab navigation with the app bar, and the side menu.
@MainActor
struct MainView: View {
    let authService: AuthService

    @Environment(SessionStore.self) private var session
    @State private var selectedTab: MainTab = .home
    @State private var isMenuOpen = false

    private var tabs: [MainTab] { MainTab.tabs(isSignedIn: session.isLoggedIn) }

    var body: some View {
        ZStack(alignment: .leading) {
            TabView(selection: $selectedTab) {
                ForEach(tabs) { tab in
                    NavigationStack {
                        tabRoot(tab)
                            .mainAppBar(showsNotifications: session.isLoggedIn) {
                                withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = true }
                            }
                    }
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
                }
            }
            .tint(AppColors.primary)

            if isMenuOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)

                GeometryReader { proxy in
                    SideMenuView(
                        authService: authService,
                        onClose: { closeMenu() }
                    )
                    .frame(width: proxy.size.width * 0.75)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .leading))
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width < -60 { closeMenu() }
                    }
                )
            }
        }
        .onChange(of: session.isLoggedIn) {
            if !tabs.contains(selectedTab) { selectedTab = .home }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: MainTab) -> some View {
        PlaceholderView(title: tab.title)
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = false }
    }
}

private struct MainAppBar: ViewModifier {
    let showsNotifications: Bool
    let onMenu: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onMenu) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel(Text("menu"))
                }
                ToolbarItem(placement: .principal) {
                    Text("app_name").font(.system(size: 18, weight: .bold))
                }
                if showsNotifications {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // Notifications screen comes later.
                        } label: {
                            Image(systemName: "bell")
                        }
                        .accessibilityLabel(Text("notifications"))
                    }
                }
            }
            .tint(AppColors.onBackground)
    }
}

private extension View {
    func mainAppBar(showsNotifications: Bool, onMenu: @escaping () -> Void) -> some View {
        modifier(MainAppBar(showsNotifications: showsNotifications, onMenu: onMenu))
    }
}
