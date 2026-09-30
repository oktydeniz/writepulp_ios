//
//  NotificationsService.swift
//  writepulp
//

import Foundation

@MainActor
final class NotificationsService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    func page(_ page: Int) async throws -> Page<NotificationItem> {
        try await api.send(NotificationsAPI.list(page: page))
    }

    /// Unread count within the first page, which is what the bell badge reflects.
    func unreadCount() async throws -> Int {
        try await page(0).content.filter { !$0.isRead }.count
    }

    func markRead(id: String) async throws {
        _ = try await api.send(NotificationsAPI.markRead(id: id))
    }

    func markAllRead() async throws {
        _ = try await api.send(NotificationsAPI.markAllRead())
    }

    func delete(id: String) async throws {
        _ = try await api.send(NotificationsAPI.delete(id: id))
    }

    func deleteAll() async throws {
        _ = try await api.send(NotificationsAPI.deleteAll())
    }

    func respondToFollowRequest(followerId: String, approve: Bool) async throws {
        _ = try await api.send(NotificationsAPI.processFollowRequest(followerId: followerId, approve: approve))
    }

    func respondToCollaborationInvite(publicationId: String, inviteId: String, accept: Bool) async throws {
        _ = try await api.send(
            NotificationsAPI.respondToCollaborationInvite(publicationId: publicationId, inviteId: inviteId, accept: accept)
        )
    }
}
