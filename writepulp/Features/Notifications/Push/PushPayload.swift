//
//  PushPayload.swift
//  writepulp
//

import Foundation

/// Custom keys the backend puts in every push (PushPayload.toData()); FCM delivers them as
/// top-level `userInfo` entries next to `aps`.
struct PushPayload: Equatable {
    let notificationId: String?
    let type: NotificationKind?
    let targetId: String?
    let arguments: String?
    let senderId: String?

    /// nil for pushes that didn't come from our backend.
    init?(userInfo: [AnyHashable: Any]) {
        func value(_ key: String) -> String? {
            let text = (userInfo[key] as? String)?.trimmingCharacters(in: .whitespaces)
            return text?.isEmpty == false ? text : nil
        }
        guard let notificationId = value("notificationId") else { return nil }
        self.notificationId = notificationId
        type = value("type").flatMap { NotificationKind(rawValue: $0) }
        targetId = value("targetId")
        arguments = value("arguments")
        senderId = value("senderId")
    }

    /// Same routing as tapping the row in the notification list, except invites and requests
    /// (accept/decline live in the list) and anything unroutable open the list itself.
    var route: MainRoute {
        guard let type, type != .followRequest, type != .collaborationInvite else { return .notifications }
        let row = NotificationItem(
            id: notificationId ?? "",
            message: "",
            arguments: arguments,
            type: type,
            targetId: targetId,
            isRead: false,
            senderHandle: nil,
            senderAvatar: nil,
            senderUUID: senderId,
            senderName: nil,
            createdAt: nil,
            publicationId: nil,
            groupId: nil,
            status: nil
        )
        if case .route(let route) = row.target { return route }
        return .notifications
    }
}
