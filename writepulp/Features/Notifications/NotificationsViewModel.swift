//
//  NotificationsViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    enum Filter: Hashable {
        case all
        case unread
    }

    private(set) var items: [NotificationItem] = []
    var filter: Filter = .all
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasMore = false
    /// Result of an action, shown as a toast.
    var toastMessage: String?

    private let service: NotificationsService
    private let badge: NotificationBadge
    /// Pages merged into `items`; after a change the same number is reloaded so the list keeps its length.
    private var loadedPages = 1

    init(service: NotificationsService, badge: NotificationBadge) {
        self.service = service
        self.badge = badge
    }

    var unreadCount: Int { items.filter { !$0.isRead }.count }
    var displayed: [NotificationItem] { filter == .unread ? items.filter { !$0.isRead } : items }

    func loadInitial() async {
        isLoading = items.isEmpty
        defer { isLoading = false }
        do {
            let page = try await service.page(0)
            items = page.content
            hasMore = !page.last
            loadedPages = 1
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.page(loadedPages)
            items += page.content
            hasMore = !page.last
            loadedPages += 1
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    /// Reloads every page loaded so far.
    func reload() async {
        var merged: [NotificationItem] = []
        var more = false
        for index in 0..<max(loadedPages, 1) {
            guard let page = try? await service.page(index) else { break }
            merged += page.content
            more = !page.last
            if page.last { break }
        }
        items = merged
        hasMore = more
        await badge.refresh()
    }

    /// Marks it read (if needed); the view handles where to go.
    func open(_ item: NotificationItem) async {
        guard !item.isRead else { return }
        if (try? await service.markRead(id: item.id)) != nil {
            await reload()
        }
    }

    func markAllRead() async {
        await perform(success: "notification_all_marked_read") { try await $0.markAllRead() }
    }

    func deleteAll() async {
        await perform(success: "notification_all_cleared") { service in
            try await service.deleteAll()
        }
        loadedPages = 1
    }

    func delete(_ item: NotificationItem) async {
        items.removeAll { $0.id == item.id }
        await perform(success: nil) { try await $0.delete(id: item.id) }
    }

    func respond(to item: NotificationItem, accept: Bool) async {
        switch item.type {
        case .followRequest:
            guard let followerId = item.senderUUID, !followerId.isEmpty else {
                toastMessage = String(localized: "notification_error_missing_sender")
                return
            }
            await perform(success: accept ? "notification_follow_accepted" : "notification_follow_declined") { service in
                try await service.respondToFollowRequest(followerId: followerId, approve: accept)
                try? await service.markRead(id: item.id)
            }
        case .collaborationInvite:
            guard let invite = item.collaborationInvite else {
                toastMessage = String(localized: "notification_error_missing_target")
                return
            }
            await perform(success: accept ? "notification_collab_accepted" : "notification_collab_declined") { service in
                try await service.respondToCollaborationInvite(
                    publicationId: invite.publicationId,
                    inviteId: invite.inviteId,
                    accept: accept
                )
                try? await service.markRead(id: item.id)
            }
        default:
            break
        }
    }

    private func perform(
        success: String.LocalizationValue?,
        _ action: (NotificationsService) async throws -> Void
    ) async {
        do {
            try await action(service)
            if let success { toastMessage = String(localized: success) }
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
        await reload()
    }
}
