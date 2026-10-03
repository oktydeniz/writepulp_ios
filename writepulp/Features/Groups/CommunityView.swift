//
//  CommunityView.swift
//  writepulp
//

import SwiftUI

/// Entry point for any community link: members get the chat, everyone else a preview with
/// join / request / withdraw.
@MainActor
struct CommunityView: View {
    let groupId: String
    let name: String
    let service: GroupsService
    let onOpen: (MainRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var group: CommunityGroup?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var toastMessage: String?
    @State private var notice: GroupsViewModel.Notice?
    @State private var chat: GroupChatViewModel

    init(groupId: String, name: String, service: GroupsService, onOpen: @escaping (MainRoute) -> Void) {
        self.groupId = groupId
        self.name = name
        self.service = service
        self.onOpen = onOpen
        _chat = State(initialValue: GroupChatViewModel(groupId: groupId, service: service))
    }

    var body: some View {
        Group {
            if let group, group.userStatus == .joined {
                GroupChatView(model: chat, name: group.name, avatar: group.groupAvatar, onOpen: onOpen) { dismiss() }
            } else if let group {
                GroupPreviewView(
                    group: group,
                    isProcessing: isProcessing,
                    onJoin: { Task { await join(group) } },
                    onWithdraw: { Task { await withdraw(group) } }
                )
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(group?.userStatus == .joined ? "" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toastMessage)
        .alert(item: $notice) { notice in
            switch notice {
            case .requestSent:
                Alert(title: Text("join_request_sent"), message: Text("we_will_send_you_a_notification_when_the_request_is_approved"))
            case .requestWithdrawn:
                Alert(title: Text("join_request_withdrawn"), message: Text("your_join_request_has_been_withdrawn"))
            }
        }
        .task { if group == nil { await load() } }
    }

    private func load() async {
        do {
            group = try await service.preview(id: groupId)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func join(_ group: CommunityGroup) async {
        await run {
            try await service.join(id: group.id)
            if group.isPrivate { notice = .requestSent }
            self.group = try await service.preview(id: group.id)
        }
    }

    private func withdraw(_ group: CommunityGroup) async {
        await run {
            try await service.withdrawRequest(id: group.id)
            notice = .requestWithdrawn
            self.group?.userStatus = .none
        }
    }

    private func run(_ action: () async throws -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await action()
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}

private struct GroupPreviewView: View {
    let group: CommunityGroup
    let isProcessing: Bool
    let onJoin: () -> Void
    let onWithdraw: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupAvatar(imagePath: group.groupAvatar, size: 96)
                    .padding(.top, 24)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.onBackground)
                            .multilineTextAlignment(.center)
                        if group.isPrivate {
                            Image(systemName: "lock.fill").foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                    Text("community_members_count".localized(group.memberCount))
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                    if group.isPrivate {
                        Text("private_community_desc")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                }

                action

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupMetaTags(categories: group.categories, tags: group.tags)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var action: some View {
        if isProcessing {
            ProgressView().frame(height: 44)
        } else if group.userStatus == .pending {
            FollowButton(title: "pending", systemImage: "clock", isActive: true, height: 44, cornerRadius: 14, fillsWidth: true, action: onWithdraw)
        } else {
            FollowButton(
                title: group.canJoinDirectly ? "join" : "request_to_join",
                systemImage: group.canJoinDirectly ? "plus" : "paperplane",
                height: 44,
                cornerRadius: 14,
                fillsWidth: true,
                action: onJoin
            )
        }
    }
}
