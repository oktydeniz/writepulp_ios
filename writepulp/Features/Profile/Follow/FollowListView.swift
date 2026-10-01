//
//  FollowListView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct FollowListView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: FollowListViewModel

    init(userId: String?, kind: FollowListKind, service: ProfileService, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: FollowListViewModel(userId: userId, kind: kind, service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("followers", selection: $model.kind) {
                ForEach(FollowListKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(model.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        .toast($model.toastMessage)
        .task(id: model.kind) { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasLoaded && model.isLoading {
            ProgressView().frame(maxHeight: .infinity)
        } else if let error = model.errorMessage, !model.hasLoaded {
            ErrorStateView(message: error) { Task { await model.refresh() } }
                .frame(maxHeight: .infinity)
        } else if model.users.isEmpty {
            EmptyStateView(systemImage: "person.2", title: "no_user_found")
                .frame(maxHeight: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(model.users) { user in
                FollowUserRow(
                    user: user,
                    onFollow: { Task { await model.toggleFollow(user) } },
                    onAccept: { Task { await model.approveRequest(from: user) } }
                )
                .contentShape(Rectangle())
                .onTapGesture { onOpen(.profile(userId: user.uuid)) }
                .listRowBackground(Color.clear)
                .onAppear {
                    if user.id == model.users.last?.id { Task { await model.loadMore() } }
                }
            }
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }
}

private struct FollowUserRow: View {
    let user: FollowUser
    let onFollow: () -> Void
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Avatar(imagePath: user.avatarImg, name: user.fullName, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                        .lineLimit(1)
                    if user.isPrivateAccount {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.primary)
                    }
                }
                Text(verbatim: "@\(user.handle)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
                if user.isFollowing && user.isFollower {
                    Text("following_you")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.appLightGray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !user.isMe {
                if user.hasPendingFollowRequest {
                    FollowButton(title: "follow_accept", systemImage: "checkmark", action: onAccept)
                }
                followButton
            }
        }
        .padding(.vertical, 6)
    }

    private var followButton: some View {
        let state = user.followState
        let title: LocalizedStringKey = switch state {
        case .following: "follow_unfollow"
        case .requested: "follow_requested"
        case .notFollowing: user.isFollower ? "follow_back" : "follow"
        }
        let icon = switch state {
        case .following: "checkmark"
        case .requested: "clock"
        case .notFollowing: "plus"
        }
        return FollowButton(title: title, systemImage: icon, isActive: state != .notFollowing, action: onFollow)
    }
}
