//
//  SideMenuView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct SideMenuView: View {
    let authService: AuthService
    let onOpen: (MainRoute) -> Void
    let onClose: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.openURL) private var openURL
    @State private var isConfirmingLogout = false

    private struct Item: Identifiable {
        enum Target {
            case screen(MainRoute)
            case link(URL)
            case signIn
        }

        let title: LocalizedStringKey
        let systemImage: String
        let target: Target
        let requiresAccount: Bool
        var id: String { systemImage + "\(title)" }
    }

    private let allItems: [Item] = [
        Item(title: "edit_profile", systemImage: "pencil", target: .screen(.editProfile), requiresAccount: true),
        Item(title: "collections", systemImage: "folder", target: .screen(.collections), requiresAccount: true),
        Item(title: "groups", systemImage: "person.3", target: .screen(.groups), requiresAccount: true),
        Item(title: "downloads_title", systemImage: "arrow.down.circle", target: .screen(.downloads), requiresAccount: true),
        Item(title: "wallet", systemImage: "wallet.pass", target: .screen(.wallet), requiresAccount: true),
        Item(title: "settings", systemImage: "gearshape", target: .screen(.settings), requiresAccount: true),
        Item(title: "privacy_policy", systemImage: "hand.raised", target: .link(AppLinks.privacyPolicy), requiresAccount: false),
        Item(title: "terms_of_service", systemImage: "doc.text", target: .link(AppLinks.termsOfService), requiresAccount: false),
        Item(title: "about_us", systemImage: "info.circle", target: .link(AppLinks.aboutUs), requiresAccount: false),
    ]

    private var items: [Item] {
        if session.isLoggedIn { return allItems }
        return allItems.filter { !$0.requiresAccount }
            + [Item(title: "login", systemImage: "arrow.right.circle", target: .signIn, requiresAccount: false)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(AppColors.onBackground)
            .accessibilityLabel(Text("back"))

            header
                .padding(.top, 8)

            Divider().padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        row(title: item.title, systemImage: item.systemImage) { open(item) }
                    }
                    if session.isLoggedIn {
                        Divider().padding(.vertical, 8)
                        row(title: "log_out", systemImage: "rectangle.portrait.and.arrow.right", isDestructive: true) {
                            isConfirmingLogout = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            AppColors.background,
            in: UnevenRoundedRectangle(bottomTrailingRadius: 16, topTrailingRadius: 16)
        )
        .alert("log_out_confirm_title", isPresented: $isConfirmingLogout) {
            Button("cancel", role: .cancel) {}
            Button("log_out", role: .destructive) {
                onClose()
                Task { await authService.logout() }
            }
        } message: {
            Text("log_out_confirm_message")
        }
    }

    private var header: some View {
        let info = session.displayInfo
        return VStack(spacing: 4) {
            AsyncImage(url: AppEnvironment.imageURL(info.avatar)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image("WritePulpLogo").resizable().scaledToFill()
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay { Circle().stroke(AppColors.surface, lineWidth: 4) }

            Text(info.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            Text(info.handle)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(
        title: LocalizedStringKey,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let color = isDestructive ? AppColors.error : AppColors.onSurface
        return Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage).frame(width: 24)
                Text(title).appTextStyle(.bodyLarge)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func open(_ item: Item) {
        switch item.target {
        case .link(let url):
            openURL(url)
            onClose()
        case .signIn:
            authService.exitGuestMode()
            onClose()
        case .screen(let route):
            onOpen(route)
        }
    }

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.top ?? 0
    }
}
