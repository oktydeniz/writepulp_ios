//
//  ProfileView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct ProfileView: View {
    /// Changes when the profile was edited elsewhere, so it reloads.
    let revision: Int
    let onOpen: (MainRoute) -> Void
    let onSignIn: () -> Void

    @State private var model: ProfileViewModel
    @State private var isShowingAvatar = false
    @State private var isCreatingCollection = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(
        userId: String?,
        revision: Int = 0,
        profileService: ProfileService,
        collectionsService: CollectionsService,
        onOpen: @escaping (MainRoute) -> Void,
        onSignIn: @escaping () -> Void
    ) {
        self.revision = revision
        self.onOpen = onOpen
        self.onSignIn = onSignIn
        _model = State(initialValue: ProfileViewModel(
            userId: userId,
            profileService: profileService,
            collectionsService: collectionsService
        ))
    }

    var body: some View {
        Group {
            if let profile = model.profile {
                content(profile)
            } else if let error = model.error, !model.isLoading {
                errorState(error)
            } else {
                ProfileSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toast($model.toastMessage)
        .task(id: revision) { await model.load() }
        .fullScreenCover(isPresented: $isShowingAvatar) {
            ImageViewer(imagePath: model.profile?.avatarImg)
        }
        .sheet(isPresented: $isCreatingCollection) {
            CollectionEditorSheet(mode: .create) { await model.saveCollection($0) }
        }
    }

    private func content(_ profile: UserProfile) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ProfileHeaderView(profile: profile) { isShowingAvatar = true }

                ProfileStatsView(profile: profile) { kind in
                    onOpen(.follows(userId: profile.isMe ? nil : profile.uuid, kind: kind))
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                actions(profile)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                if profile.isContentVisible {
                    ProfileTabBar(selection: $model.tab)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                    tabContent(profile)
                } else {
                    PrivateAccountPlaceholder()
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func actions(_ profile: UserProfile) -> some View {
        if profile.isMe {
            Button { onOpen(.editProfile) } label: {
                Label("edit_profile", systemImage: "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColors.secondaryContainer, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            let state = profile.followState
            FollowButton(
                title: state == .requested ? "pending" : state == .following ? "following" : "follow",
                systemImage: state == .requested ? "clock" : state == .following ? "checkmark" : "plus",
                isActive: state != .notFollowing,
                height: 48,
                cornerRadius: 12,
                fillsWidth: true
            ) {
                Task { await model.toggleFollow() }
            }
            .disabled(model.isFollowBusy)
        }
    }

    @ViewBuilder
    private func tabContent(_ profile: UserProfile) -> some View {
        switch model.tab {
        case .about:
            ProfileAboutView(profile: profile)
                .padding(.horizontal, 18)
        case .works:
            works(isMe: profile.isMe)
        case .lists:
            lists(isMe: profile.isMe)
        }
    }

    @ViewBuilder
    private func works(isMe: Bool) -> some View {
        if !model.works.hasLoaded {
            PublicationGridSkeleton(count: 4)
        } else if model.works.isEmpty {
            EmptyStateView(systemImage: "pencil.line", title: isMe ? "works_empty_title_me" : "works_empty_title_other")
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(model.works.items.enumerated()), id: \.element.id) { index, publication in
                    Button { onOpen(.publication(id: publication.uuid)) } label: {
                        PublicationCard(content: publication.cardContent)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .onAppear {
                        if index >= model.works.items.count - 4 { Task { await model.loadMoreWorks() } }
                    }
                }
            }
            .padding(.horizontal, 12)
            if model.isLoadingWorks {
                ProgressView().padding(16)
            }
        }
    }

    @ViewBuilder
    private func lists(isMe: Bool) -> some View {
        if model.collections.isEmpty {
            EmptyStateView(
                systemImage: "folder",
                title: "no_collections_found",
                message: isMe ? "you_haven_t_created_collections_yet" : nil,
                actionTitle: isMe ? "create_new_collection" : nil,
                action: { isCreatingCollection = true }
            )
        } else {
            VStack(spacing: 12) {
                ForEach(model.collections) { collection in
                    let canOpen = isMe || !collection.isPrivate
                    Button { onOpen(.collection(id: collection.uuid, name: collection.displayName)) } label: {
                        CollectionRow(collection: collection, showsOwner: !isMe)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canOpen)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func errorState(_ error: Error) -> some View {
        Group {
            if (error as? APIError)?.requiresSignIn == true {
                VStack(spacing: 12) {
                    Text("profile_login_required")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                    TextLinkButton(title: "login", color: AppColors.primary, action: onSignIn)
                }
                .padding(32)
            } else {
                ErrorStateView(message: error.localizedDescription) { Task { await model.load() } }
            }
        }
    }
}

/// Cover, avatar, name, stats and the action button.
private struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                SkeletonBlock(height: 210, cornerRadius: 24)
                    .frame(maxHeight: .infinity, alignment: .top)
                Circle()
                    .fill(AppColors.skeleton)
                    .frame(width: 110, height: 110)
                    .overlay { Circle().stroke(AppColors.background, lineWidth: 4) }
            }
            .frame(height: 260)
            SkeletonBlock(width: 180, height: 22)
            SkeletonBlock(width: 110, height: 14)
            SkeletonBlock(height: 70, cornerRadius: 16).padding(.horizontal, 18)
            SkeletonBlock(height: 48, cornerRadius: 12).padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shimmering()
    }
}
