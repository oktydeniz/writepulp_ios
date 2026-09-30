//
//  NotificationModels.swift
//  writepulp
//

import SwiftUI

enum NotificationKind: String, Decodable {
    case follow = "FOLLOW"
    case followRequest = "FOLLOW_REQUEST"
    case followAccept = "FOLLOW_ACCEPT"
    case collaborationInvite = "COLLABORATION_INVITE"
    case collaborationAccept = "COLLABORATION_ACCEPT"
    case system = "SYSTEM"
    case message = "MESSAGE"
    case externalURL = "EXTERNAL_URL"
    case roleChanged = "ROLE_CHANGED"
    case like = "LIKE"
    case replyComment = "REPLY_COMMENT"
    case campaign = "CAMPAIGN"
    case noteFlow = "NOTE_FLOW"
    case newSection = "NEW_SECTION"
    case newPublication = "NEW_PUBLICATION"
    case collectionUpdate = "COLLECTION_UPDATE"
    case groupRequest = "GROUP_REQUEST"
    case groupMessage = "GROUP_MESSAGE"
    case groupRoleChanged = "GROUP_ROLE_CHANGED"
    case groupJoinAccepted = "GROUP_JOIN_ACCEPTED"
    case coinReward = "COIN_REWARD"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NotificationKind(rawValue: raw) ?? .unknown
    }

    /// Headline when the notification has no sender.
    var label: LocalizedStringKey {
        guard self != .unknown else { return "notifications" }
        // Built as a String first: an interpolated LocalizedStringKey literal would become a format key.
        let key = "notification_type_" + rawValue.lowercased()
        return LocalizedStringKey(key)
    }

    var systemImage: String {
        switch self {
        case .follow, .followRequest, .followAccept: "person.badge.plus"
        case .collaborationInvite, .collaborationAccept, .groupRequest: "person.3.fill"
        case .message: "envelope.fill"
        case .externalURL: "link"
        case .roleChanged, .groupRoleChanged: "shield.fill"
        case .like: "heart.fill"
        case .replyComment, .groupMessage: "bubble.left.fill"
        case .campaign: "megaphone.fill"
        case .noteFlow: "doc.text.fill"
        case .newSection, .newPublication: "book.fill"
        case .collectionUpdate: "bookmark.fill"
        case .coinReward: "dollarsign.circle.fill"
        default: "bell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .follow, .followRequest, .followAccept: Color(hex: 0x3DAA72)
        case .collaborationInvite, .collaborationAccept: Color(hex: 0x7C5CBF)
        case .externalURL: Color(hex: 0x2563EB)
        case .like: Color(hex: 0xD95050)
        case .campaign, .coinReward: Color(hex: 0xE8B84B)
        default: Color(hex: 0x60809E)
        }
    }
}

struct NotificationItem: Decodable, Identifiable, Equatable {
    let id: String
    let message: String
    /// Pipe-separated, e.g. "title|publicationId" or "groupName|…" depending on the type.
    let arguments: String?
    let type: NotificationKind
    let targetId: String?
    let isRead: Bool
    let senderHandle: String?
    let senderAvatar: String?
    let senderUUID: String?
    let senderName: String?
    let createdAt: String?
    let publicationId: String?
    let groupId: String?
    /// Accept/decline stay visible while this is blank or PENDING.
    let status: String?

    var headline: String? {
        [senderName, senderHandle]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    // MARK: - Actions

    private static let terminalStatuses: Set<String> = ["ACCEPTED", "REJECTED", "DECLINED", "CANCELLED", "EXPIRED", "DELETED"]

    var showsActionButtons: Bool {
        guard type == .followRequest || type == .collaborationInvite else { return false }
        let status = (status ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        return status.isEmpty || !Self.terminalStatuses.contains(status)
    }

    /// COLLABORATION_INVITE: targetId = inviteId, arguments = "title|publicationId".
    var collaborationInvite: (inviteId: String, publicationId: String)? {
        guard let inviteId = Self.uuid(targetId), let publicationId = Self.uuid(Self.lastPart(arguments)) else { return nil }
        return (inviteId, publicationId)
    }

    // MARK: - Navigation

    enum Target: Equatable {
        case route(MainRoute)
        case url(URL)
        case none
    }

    var target: Target {
        switch type {
        case .follow, .followRequest, .followAccept, .like, .replyComment:
            return Self.nonEmpty(senderUUID).map { .route(.profile(userId: $0)) } ?? .none
        case .collaborationInvite:
            return (Self.uuid(publicationId) ?? collaborationInvite?.publicationId).map { .route(.publication(id: $0)) } ?? .none
        case .collaborationAccept:
            let id = Self.uuid(publicationId) ?? Self.uuid(targetId) ?? Self.uuid(Self.lastPart(arguments))
            return id.map { .route(.publication(id: $0)) } ?? .none
        case .externalURL:
            guard let target = targetId, target.hasPrefix("http://") || target.hasPrefix("https://"),
                  let url = URL(string: target) else { return .none }
            return .url(url)
        case .newPublication, .newSection:
            return (Self.uuid(publicationId) ?? Self.uuid(targetId)).map { .route(.publication(id: $0)) } ?? .none
        case .groupRequest, .groupMessage, .groupRoleChanged, .groupJoinAccepted:
            let groupName = argument(at: type == .groupRequest ? 1 : 0) ?? ""
            return (Self.uuid(groupId) ?? Self.uuid(targetId)).map { .route(.community(id: $0, name: groupName)) } ?? .none
        case .roleChanged:
            return Self.uuid(targetId).map { .route(.publication(id: $0)) } ?? .none
        case .collectionUpdate:
            return Self.uuid(targetId).map { .route(.collection(id: $0, name: argument(at: 1) ?? "")) } ?? .none
        case .coinReward:
            return .route(.wallet)
        default:
            return .none
        }
    }

    // MARK: - Helpers

    private func argument(at index: Int) -> String? {
        guard let parts = arguments?.split(separator: "|", omittingEmptySubsequences: false),
              parts.indices.contains(index) else { return nil }
        return Self.nonEmpty(String(parts[index]))
    }

    private static func lastPart(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.split(separator: "|", omittingEmptySubsequences: false).last.map(String.init)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func uuid(_ value: String?) -> String? {
        guard let value = nonEmpty(value), UUID(uuidString: value) != nil else { return nil }
        return value
    }
}
