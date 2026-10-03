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
    /// Bumped after the user edits their profile or collections, so open profiles reload.
    @State private var profileRevision = 0

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
        .task(id: "\(session.userId ?? "")-\(dependencies.networkMonitor.isOnUnmeteredNetwork)") {
            await dependencies.downloadManager.prepare()
            await dependencies.downloadManager.refreshStaleIfNeeded()
        }
        .task(id: session.isLoggedIn) {
            guard session.isLoggedIn else { return }
            await PushNotifications.shared.requestAuthorization()
            await PushNotifications.shared.registerToken()
        }
        // A tapped push (possibly from a cold start) opens once the shell is on screen.
        .task(id: PushNotifications.shared.pendingPayload) {
            if let payload = PushNotifications.shared.consumePending() {
                open(payload.route)
                if let id = payload.notificationId {
                    try? await dependencies.notificationsService.markRead(id: id)
                    await badge.refresh()
                }
            }
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
        case .pocket:
            PocketView(
                service: dependencies.pocketService,
                onOpen: { open($0) },
                onExplore: { selectedTab = .search }
            )
        case .search:
            SearchView(service: dependencies.searchService, onOpen: { open($0) })
        case .profile:
            profileView(userId: nil)
        }
    }

    private func profileView(userId: String?) -> some View {
        ProfileView(
            userId: userId,
            revision: profileRevision,
            profileService: dependencies.profileService,
            collectionsService: dependencies.collectionsService,
            onOpen: { open($0) },
            onSignIn: { dependencies.authService.exitGuestMode() }
        )
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
        case .publication(let id):
            PublicationDetailView(
                publicationId: id,
                service: dependencies.publicationService,
                collectionsService: dependencies.collectionsService,
                downloads: dependencies.downloadManager,
                onOpen: { open($0) },
                onSignIn: { dependencies.authService.exitGuestMode() }
            )
        case .reader(let publicationId, let type, let chapterId):
            ReaderScreen(
                publicationId: publicationId,
                type: type,
                chapterId: chapterId,
                service: dependencies.readerService,
                onOpen: { open($0) },
                onSignIn: { dependencies.authService.exitGuestMode() }
            )
        case .profile(let userId):
            profileView(userId: userId == session.userId ? nil : userId)
        case .follows(let userId, let kind):
            FollowListView(userId: userId, kind: kind, service: dependencies.profileService, onOpen: { open($0) })
        case .community, .groups:
            PlaceholderView(title: "groups")
        case .collections:
            CollectionsView(
                service: dependencies.collectionsService,
                onOpen: { open($0) },
                onChange: { profileRevision += 1 }
            )
        case .categoryExplore(let slug, let title):
            CategoryExploreView(slug: slug, title: title, service: dependencies.searchService, onOpen: { open($0) })
        case .collection(let id, let name):
            CollectionDetailView(collectionId: id, title: name, service: dependencies.collectionsService, onOpen: { open($0) })
        case .editProfile:
            EditProfileView(service: dependencies.profileService, onSaved: { profileRevision += 1 })
        case .downloads:
            DownloadsView(
                manager: dependencies.downloadManager,
                network: dependencies.networkMonitor,
                preferences: preferences,
                onOpen: { open($0) }
            )
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
