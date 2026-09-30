//
//  NotificationsAPI.swift
//  writepulp
//

import Foundation

enum NotificationsAPI {
    static let pageSize = 20

    static func list(page: Int) -> Endpoint<Page<NotificationItem>> {
        Endpoint(
            path: "notifications",
            query: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(pageSize)")]
        )
    }

    static func markRead(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "notifications/\(id)/read", method: .patch)
    }

    static func markAllRead() -> Endpoint<EmptyResponse> {
        Endpoint(path: "notifications/read-all", method: .patch)
    }

    static func delete(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "notifications/\(id)", method: .delete)
    }

    static func deleteAll() -> Endpoint<EmptyResponse> {
        Endpoint(path: "notifications/all", method: .delete)
    }

    static func processFollowRequest(followerId: String, approve: Bool) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "follows/process-request/\(followerId)",
            method: .post,
            query: [URLQueryItem(name: "approve", value: approve ? "true" : "false")]
        )
    }

    struct DeviceToken: Encodable {
        let token: String
        var platform: String? = "IOS"
    }

    static func registerDevice(token: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "devices/tokens", method: .post, body: DeviceToken(token: token))
    }

    static func unregisterDevice(token: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "devices/tokens", method: .delete, body: DeviceToken(token: token, platform: nil))
    }

    static func respondToCollaborationInvite(publicationId: String, inviteId: String, accept: Bool) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "publications/\(publicationId)/collaborators/invites/\(inviteId)/\(accept ? "accept" : "reject")",
            method: .patch
        )
    }
}
