//
//  BlockedUsersView.swift
//  writepulp
//

import SwiftUI

/// Settings → Blocked users: everyone the user blocked, with an unblock button each.
struct BlockedUsersView: View {
    @Environment(\.moderation) private var moderation
    @State private var users = PagedList<BlockedUser>()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var busyIds: Set<String> = []

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(AppColors.error)
            }
            ForEach(users.items) { blocked in
                HStack(spacing: 12) {
                    Avatar(imagePath: blocked.user.avatarImg, name: blocked.user.fullName, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(blocked.user.fullName).font(.system(size: 15, weight: .semibold))
                        Text(verbatim: "@\(blocked.user.handle)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.onSurface.opacity(0.6))
                    }
                    Spacer()
                    Button("unblock") { Task { await unblock(blocked) } }
                        .buttonStyle(.bordered)
                        .disabled(busyIds.contains(blocked.id))
                }
                .onAppear {
                    if blocked.id == users.items.last?.id { Task { await loadMore() } }
                }
            }
        }
        .overlay {
            if isLoading && users.isEmpty {
                ProgressView()
            } else if users.hasLoaded && users.isEmpty {
                EmptyStateView(systemImage: "hand.raised", title: "blocked_users_empty")
            }
        }
        .navigationTitle(Text("blocked_users_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func reload() async {
        guard let moderation else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var list = PagedList<BlockedUser>()
            list.apply(try await moderation.blockedUsers(page: 0), replacing: true)
            users = list
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let moderation, users.hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if let page = try? await moderation.blockedUsers(page: users.nextPage) {
            users.apply(page, replacing: false)
        }
    }

    private func unblock(_ blocked: BlockedUser) async {
        guard let moderation else { return }
        busyIds.insert(blocked.id)
        defer { busyIds.remove(blocked.id) }
        do {
            try await moderation.unblock(userId: blocked.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
