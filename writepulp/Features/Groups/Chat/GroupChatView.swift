//
//  GroupChatView.swift
//  writepulp
//

import SwiftUI

/// A community's chat for its members. The list is drawn upside down (newest at the visual
/// bottom), so loading older messages appends without moving what's on screen.
@MainActor
struct GroupChatView: View {
    @Bindable var model: GroupChatViewModel
    let name: String
    let avatar: String?
    let onOpen: (MainRoute) -> Void
    let onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingRules = false
    @State private var isConfirmingLeave = false
    @State private var isConfirmingDelete = false
    @State private var viewerImage: String?
    @State private var reportTarget: ReportTarget?
    @State private var pendingBlock: GroupMessage?
    @Environment(\.moderation) private var moderation
    /// Becomes true once the list has been placed at the first unread message (or the bottom);
    /// reaching the bottom only marks messages read after that.
    @State private var hasPositioned = false

    private static let newestAnchor = "newest"

    var body: some View {
        VStack(spacing: 0) {
            // Keeps the (flipped) list from extending under the navigation bar: flipped, the
            // bar's inset would land at the bottom and the newest messages would hide behind it.
            Divider()
            content
            GroupChatComposer(model: model) { model.isAtBottom = true }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbar }
        .toast($model.toastMessage)
        .reportSheet($reportTarget)
        .confirmationDialog("block_confirm_title", isPresented: Binding(
            get: { pendingBlock != nil },
            set: { if !$0 { pendingBlock = nil } }
        ), titleVisibility: .visible) {
            Button("block", role: .destructive) {
                if let message = pendingBlock { Task { await block(message.senderId) } }
            }
        } message: {
            Text("block_confirm_message")
        }
        .loadingOverlay(model.isBusy)
        .sheet(isPresented: $isShowingRules) { GroupRulesSheet(rules: model.detail?.rules ?? []) }
        .fullScreenCover(isPresented: Binding(get: { viewerImage != nil }, set: { if !$0 { viewerImage = nil } })) {
            ImageViewer(imagePath: viewerImage)
        }
        .alert("are_you_sure", isPresented: $isConfirmingLeave) {
            Button("cancel", role: .cancel) {}
            Button("leave_group", role: .destructive) { Task { await model.leave() } }
        } message: {
            Text("you_will_no_longer_be_a_member")
        }
        .alert("are_you_sure", isPresented: $isConfirmingDelete) {
            Button("cancel", role: .cancel) {}
            Button("delete_community", role: .destructive) { Task { await model.deleteGroup() } }
        } message: {
            Text("you_will_delete_this_community")
        }
        .task { await model.start() }
        .onAppear { Task { await model.refreshDetail() } }
        .task { await model.listen() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.reconnect() } }
        }
        .onChange(of: model.didExit) { _, didExit in
            if didExit { onExit() }
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var content: some View {
        if let error = model.errorMessage {
            ErrorStateView(message: error) { Task { await model.retry() } }
                .frame(maxHeight: .infinity)
        } else if !model.hasLoadedHistory {
            ChatSkeleton()
        } else if model.messages.isEmpty {
            EmptyStateView(systemImage: "bubble.left.and.bubble.right", title: "no_messages_yet")
                .frame(maxHeight: .infinity)
        } else {
            messageList
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    Color.clear.frame(height: 1)
                        .id(Self.newestAnchor)
                        .onAppear { reachedBottom() }
                        .onDisappear { model.isAtBottom = false }
                    ForEach(visibleMessages) { message in
                        row(message).flipped()
                    }
                    if model.isLoadingOlder {
                        ProgressView().padding(.vertical, 8).flipped()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .flipped()
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottomTrailing) {
                if !model.isAtBottom {
                    scrollToBottomButton { withAnimation { proxy.scrollTo(Self.newestAnchor) } }
                }
            }
            .task(id: model.hasLoadedHistory) {
                guard model.hasLoadedHistory, !hasPositioned else { return }
                if let unread = model.firstUnreadId, unread != model.messages.first?.id {
                    proxy.scrollTo(unread, anchor: .center)
                }
                // Lets the jump settle before "at the bottom" can mark things read.
                try? await Task.sleep(for: .milliseconds(400))
                hasPositioned = true
                if model.isAtBottom { await model.markAsRead() }
            }
            .onChange(of: model.messages.first?.id) {
                // Follow new messages when already at the bottom.
                if model.isAtBottom { withAnimation { proxy.scrollTo(Self.newestAnchor) } }
            }
        }
    }

    private func row(_ message: GroupMessage) -> some View {
        let isMine = model.isMine(message)
        return VStack(spacing: 8) {
            if message.id == model.firstUnreadId {
                UnreadDivider(count: model.unreadCount)
            }
            GroupMessageBubble(message: message, isMine: isMine) { viewerImage = $0 }
                .contextMenu { menu(for: message) }
        }
        .id(message.id)
        .onAppear {
            if message.id == model.messages.last?.id { Task { await model.loadOlder() } }
        }
    }

    @ViewBuilder
    private func menu(for message: GroupMessage) -> some View {
        if model.canSend && !message.isLeft {
            Button { model.replyTarget = message } label: { Label("reply", systemImage: "arrowshape.turn.up.left") }
        }
        if !message.content.isEmpty {
            Button { UIPasteboard.general.string = message.content } label: { Label("copy", systemImage: "doc.on.doc") }
        }
        if !model.isMine(message) && !message.isLeft && moderation?.currentUserId != nil {
            Button { reportTarget = ReportTarget(type: .groupMessage, id: message.id) } label: {
                Label("report_message", systemImage: "flag")
            }
            Button(role: .destructive) { pendingBlock = message } label: {
                Label("block_sender", systemImage: "hand.raised")
            }
        }
        // The server lets owners and admins delete messages.
        if model.canManage {
            Button(role: .destructive) { Task { await model.delete(message) } } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    /// Messages this viewer reported, or from someone blocked either way, including ones that
    /// arrive live over the socket, which the server can't filter per viewer.
    private var visibleMessages: [GroupMessage] {
        guard let moderation else { return model.messages }
        return model.messages.filter {
            !moderation.isHidden(ReportTarget(type: .groupMessage, id: $0.id), authorId: $0.senderId)
        }
    }

    private func block(_ userId: String) async {
        do {
            try await moderation?.block(userId: userId)
            model.toastMessage = String(localized: "block_done")
        } catch {
            model.toastMessage = error.localizedDescription
        }
    }

    private func reachedBottom() {
        model.isAtBottom = true
        if hasPositioned { Task { await model.markAsRead() } }
    }

    private func scrollToBottomButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.onPrimary)
                .frame(width: 40, height: 40)
                .background(AppColors.primary, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .overlay(alignment: .topTrailing) {
                    if model.unreadCount > 0 {
                        Text(String(model.unreadCount))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.error, in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .padding(16)
        .accessibilityLabel(Text("scroll_to_bottom"))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                GroupAvatar(imagePath: model.detail?.groupAvatar ?? avatar, size: 30)
                Text(model.detail?.name ?? name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { isShowingRules = true } label: { Image(systemName: "info.circle") }
                .accessibilityLabel(Text("rules"))
            Menu {
                Button { onOpen(.groupMembers(id: model.groupId, role: model.role)) } label: {
                    Label("members", systemImage: "person.2")
                }
                if model.canManage {
                    Button { onOpen(.editGroup(id: model.groupId)) } label: {
                        Label("edit_community", systemImage: "square.and.pencil")
                    }
                }
                if !model.isOwner {
                    Button { reportTarget = ReportTarget(type: .group, id: model.groupId) } label: {
                        Label("report_group", systemImage: "flag")
                    }
                }
                Divider()
                // An owner can leave only if there's an admin to take over; the server says so otherwise.
                Button(role: .destructive) { isConfirmingLeave = true } label: {
                    Label("leave_group", systemImage: "rectangle.portrait.and.arrow.right")
                }
                if model.isOwner {
                    Button(role: .destructive) { isConfirmingDelete = true } label: {
                        Label("delete_community", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(Text("downloads_more_actions"))
        }
    }
}

private extension View {
    func flipped() -> some View {
        scaleEffect(x: 1, y: -1)
    }
}
