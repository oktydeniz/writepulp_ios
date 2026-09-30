//
//  MainView.swift
//  writepulp
//

import SwiftUI

/// Signed-in (or guest) shell: tab bar, per-tab navigation with the app bar, the side menu,
/// and the notification badge polling.
@MainActor
struct MainView: View {
    let dependencies: AppDependencies

    @Environment(SessionStore.self) private var session
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: MainTab = .home
    @State private var isMenuOpen = false
    @State private var paths: [MainTab: [MainRoute]] = [:]
    @State private var badge: NotificationBadge

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _badge = State(initialValue: NotificationBadge(service: dependencies.notificationsService))
    }

    private var tabs: [MainTab] { MainTab.tabs(isSignedIn: session.isLoggedIn) }

    var body: some View {
        ZStack(alignment: .leading) {
            TabView(selection: $selectedTab) {
                ForEach(tabs) { tab in
                    NavigationStack(path: path(for: tab)) {
                        tabRoot(tab)
                            .mainAppBar(
                                showsNotifications: session.isLoggedIn,
                                hasUnread: badge.hasUnread,
                                onMenu: { withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = true } },
                                onNotifications: { open(.notifications) }
                            )
                            .navigationDestination(for: MainRoute.self) { destination($0) }
                    }
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
                }
            }
            .tint(AppColors.primary)

            if isMenuOpen {
                sideMenu
            }
        }
        .onChange(of: session.isLoggedIn) {
            if !tabs.contains(selectedTab) { selectedTab = .home }
        }
        // Restarts when sign-in or foreground state changes; stops when the shell goes away.
        .task(id: "\(session.isLoggedIn)-\(scenePhase == .active)") {
            await badge.poll(isSignedIn: session.isLoggedIn && scenePhase == .active)
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private func tabRoot(_ tab: MainTab) -> some View {
        switch tab {
        case .home:
            HomeView(
                service: dependencies.homeService,
                preferences: preferences,
                onOpen: { open($0) },
                onSignIn: { dependencies.authService.exitGuestMode() }
            )
        default:
            PlaceholderView(title: tab.title)
        }
    }

    // MARK: - Navigation

    private func path(for tab: MainTab) -> Binding<[MainRoute]> {
        Binding(
            get: { paths[tab] ?? [] },
            set: { paths[tab] = $0 }
        )
    }

    /// Pushes onto the selected tab's stack.
    private func open(_ route: MainRoute) {
        paths[selectedTab, default: []].append(route)
    }

    @ViewBuilder
    private func destination(_ route: MainRoute) -> some View {
        switch route {
        case .homeSection(let key, let title, let type):
            HomeSectionView(
                source: .section(key: key),
                title: title,
                typeFilter: type,
                service: dependencies.homeService,
                onOpen: { open($0) }
            )
        case .authorsOfTheWeek:
            HomeSectionView(
                source: .authorsOfTheWeek,
                title: String(localized: "home_authors_of_week"),
                typeFilter: nil,
                service: dependencies.homeService,
                onOpen: { open($0) }
            )
        case .notifications:
            NotificationsView(service: dependencies.notificationsService, badge: badge, onOpen: { open($0) })
        case .publication:
            PlaceholderView(title: "content_detail")
        case .profile:
            PlaceholderView(title: "profile")
        case .community, .groups:
            PlaceholderView(title: "groups")
        case .collection, .collections:
            PlaceholderView(title: "collections")
        case .editProfile:
            PlaceholderView(title: "edit_profile")
        case .downloads:
            PlaceholderView(title: "downloads_title")
        case .wallet:
            WalletView(service: dependencies.walletService)
        case .settings:
            SettingsView(service: dependencies.settingsService, preferences: preferences)
        }
    }

    // MARK: - Side menu

    private var sideMenu: some View {
        Group {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { closeMenu() }
                .transition(.opacity)

            GeometryReader { proxy in
                SideMenuView(
                    authService: dependencies.authService,
                    onOpen: { route in
                        closeMenu()
                        open(route)
                    },
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

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = false }
    }
}

private struct MainAppBar: ViewModifier {
    let showsNotifications: Bool
    let hasUnread: Bool
    let onMenu: () -> Void
    let onNotifications: () -> Void

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
                        Button(action: onNotifications) {
                            Image(systemName: "bell")
                                .overlay(alignment: .topTrailing) {
                                    if hasUnread {
                                        Circle()
                                            .fill(AppColors.error)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                        }
                        .accessibilityLabel(Text("notifications"))
                    }
                }
            }
            .tint(AppColors.onBackground)
    }
}

private extension View {
    func mainAppBar(
        showsNotifications: Bool,
        hasUnread: Bool,
        onMenu: @escaping () -> Void,
        onNotifications: @escaping () -> Void
    ) -> some View {
        modifier(MainAppBar(
            showsNotifications: showsNotifications,
            hasUnread: hasUnread,
            onMenu: onMenu,
            onNotifications: onNotifications
        ))
    }
}
