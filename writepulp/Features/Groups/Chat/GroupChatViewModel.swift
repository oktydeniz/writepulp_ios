//
//  GroupChatViewModel.swift
//  writepulp
//

import Observation
import UIKit

@MainActor
@Observable
final class GroupChatViewModel {
    let groupId: String
    private(set) var detail: GroupDetail?
    /// Newest first.
    private(set) var messages: [GroupMessage] = []
    private(set) var hasLoadedHistory = false
    private(set) var isLoadingOlder = false
    private(set) var restrictedMessaging = false
    private(set) var isSending = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    /// Set when the user left or deleted the group; the screen closes.
    private(set) var didExit = false
    var draft = ""
    var replyTarget: GroupMessage?
    var attachment: UIImage?
    var toastMessage: String?
    /// Kept up to date by the screen: live messages arriving while scrolled up stay unread.
    var isAtBottom = true

    private let service: GroupsService
    private var nextPage = 0
    private var hasOlder = true

    init(groupId: String, service: GroupsService) {
        self.groupId = groupId
        self.service = service
    }

    var role: GroupRole { detail?.effectiveRole ?? .member }
    var canSend: Bool { !restrictedMessaging || role != .member }
    var canManage: Bool { role.canManage }
    var isOwner: Bool { detail?.isOwner == true }

    var canSubmit: Bool {
        canSend && !isSending && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil)
    }

    func isMine(_ message: GroupMessage) -> Bool {
        message.senderId == service.currentUserId
    }

    /// The oldest unread message from someone else, where the "unread" divider goes.
    var firstUnreadId: String? {
        messages.last { !$0.isRead && !isMine($0) }?.id
    }

    var unreadCount: Int {
        messages.filter { !$0.isRead && !isMine($0) }.count
    }

    // MARK: - Loading

    func start() async {
        guard !hasLoadedHistory else { return }
        async let detailRequest: Void = loadDetail()
        async let historyRequest: Void = loadOlder()
        _ = await (detailRequest, historyRequest)
    }

    private func loadDetail() async {
        do {
            let loaded = try await service.detail(id: groupId)
            detail = loaded
            restrictedMessaging = loaded.restrictedMessaging
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func loadOlder() async {
        guard hasOlder, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await service.history(groupId: groupId, page: nextPage)
            merge(page.content)
            nextPage += 1
            hasOlder = !page.last
            hasLoadedHistory = true
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if !hasLoadedHistory { errorMessage = error.localizedDescription }
        }
    }

    /// Picks up changes made elsewhere, e.g. in the settings screen.
    func refreshDetail() async {
        guard detail != nil else { return }
        await loadDetail()
    }

    func retry() async {
        errorMessage = nil
        await start()
    }

    /// Messages sent while the socket was down (or over REST) are picked up from the latest page.
    private func refreshLatest() async {
        guard let page = try? await service.history(groupId: groupId, page: 0) else { return }
        merge(page.content)
    }

    private func merge(_ incoming: [GroupMessage]) {
        var byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for message in incoming { byId[message.id] = message }
        messages = byId.values.sorted { $0.sentAt > $1.sentAt }
    }

    // MARK: - Live updates

    /// Runs until cancelled (the screen goes away).
    func listen() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.listenToMessages() }
            group.addTask { await self.listenToSignals() }
        }
    }

    private func listenToMessages() async {
        for await event in await service.socket.subscribe("/topic/group.\(groupId)") {
            switch event {
            case .message(let data):
                guard var message = try? JSONDecoder().decode(GroupMessage.self, from: data),
                      message.communityId.caseInsensitiveCompare(groupId) == .orderedSame else { continue }
                let isOthers = !isMine(message)
                if isOthers { message.isRead = isAtBottom }
                merge([message])
                if isOthers, isAtBottom { await service.markAsRead(groupId: groupId) }
            case .reconnected:
                await refreshLatest()
            }
        }
    }

    private func listenToSignals() async {
        for await event in await service.socket.subscribe("/topic/group.\(groupId).signals") {
            guard case .message(let data) = event,
                  let signal = try? JSONDecoder().decode(GroupSignal.self, from: data),
                  signal.type == "MESSAGING_STATUS",
                  let restricted = signal.restrictedMessaging else { continue }
            restrictedMessaging = restricted
        }
    }

    func reconnect() async {
        await service.socket.reconnectIfNeeded()
    }

    // MARK: - Actions

    func markAsRead() async {
        guard unreadCount > 0 else { return }
        for index in messages.indices where !isMine(messages[index]) {
            messages[index].isRead = true
        }
        await service.markAsRead(groupId: groupId)
    }

    func send() async {
        guard canSubmit else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = attachment
        let reply = replyTarget
        isSending = true
        defer { isSending = false }
        do {
            var imagePath: String?
            if let image {
                guard let jpeg = image.compressedJPEG() else { return }
                imagePath = try await service.uploadImage(jpeg)
            }
            let request = SendGroupMessageRequest(content: text, imageUrl: imagePath, replyToId: reply?.id)
            draft = ""
            attachment = nil
            replyTarget = nil
            if try await service.send(groupId: groupId, request) {
                await refreshLatest()
            }
            await markAsRead()
        } catch {
            // Keep what the user wrote so they can try again.
            if draft.isEmpty { draft = text }
            if attachment == nil { attachment = image }
            if replyTarget == nil { replyTarget = reply }
            toastMessage = error.localizedDescription
        }
    }

    func delete(_ message: GroupMessage) async {
        do {
            try await service.deleteMessage(id: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func leave() async {
        await exit { try await self.service.leave(id: self.groupId) }
    }

    func deleteGroup() async {
        await exit { try await self.service.delete(id: self.groupId) }
    }

    private func exit(_ action: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
            didExit = true
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}
