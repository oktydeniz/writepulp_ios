//
//  GroupModels.swift
//  writepulp
//

import SwiftUI

enum GroupRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case moderator = "MODERATOR"
    case member = "MEMBER"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupRole(rawValue: raw.uppercased()) ?? .member
    }

    /// Owners and admins manage the group; moderators can still write when messaging is restricted.
    var canManage: Bool { self == .owner || self == .admin }
}

extension Optional where Wrapped == GroupRole {
    /// nil: the sender has left the group.
    var titleKey: LocalizedStringKey {
        switch self {
        case .owner: "role_owner"
        case .admin: "role_admin"
        case .moderator: "role_moderator"
        case .member: "role_member"
        case nil: "role_old_member"
        }
    }

    var color: Color {
        switch self {
        case .owner: Color(hex: 0xE53935)
        case .admin: Color(hex: 0x8E24AA)
        case .moderator: Color(hex: 0x1E88E5)
        case .member: Color(hex: 0xFB8C00)
        case nil: Color(hex: 0x757575)
        }
    }
}

enum GroupUserStatus: String, Decodable {
    case joined = "JOINED"
    case pending = "PENDING"
    case none = "NONE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupUserStatus(rawValue: raw.uppercased()) ?? .none
    }
}

typealias GroupCategory = CategoryGroup.Category

/// List item of explore / mine / owned / search, and `community/{id}/preview`.
struct CommunityGroup: Decodable, Identifiable, Hashable {
    let uuid: String
    let name: String
    let description: String?
    let isPrivate: Bool
    var memberCount: Int
    let groupAvatar: String?
    let categories: [GroupCategory]
    let tags: [String]
    var userStatus: GroupUserStatus
    let canJoinDirectly: Bool
    let unreadCount: Int

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, isPrivate, memberCount, groupAvatar, categories, tags,
             userStatus, canJoinDirectly, unreadCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        groupAvatar = try c.decodeIfPresent(String.self, forKey: .groupAvatar)
        categories = (try? c.decodeIfPresent([GroupCategory].self, forKey: .categories)) ?? []
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        userStatus = (try? c.decodeIfPresent(GroupUserStatus.self, forKey: .userStatus)) ?? .none
        canJoinDirectly = try c.decodeIfPresent(Bool.self, forKey: .canJoinDirectly) ?? false
        unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
    }
}

/// `community/{id}/detail`. `role` is nil when the viewer isn't a member.
struct GroupDetail: Decodable {
    let uuid: String
    let name: String
    let description: String?
    let isPrivate: Bool
    let restrictedMessaging: Bool
    let memberCount: Int
    let groupAvatar: String?
    let categories: [GroupCategory]
    let tags: [String]
    let rules: [String]
    let role: GroupRole?
    let isOwner: Bool

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, isPrivate, restrictedMessaging, memberCount, groupAvatar,
             categories, tags, rules, role, isOwner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        restrictedMessaging = try c.decodeIfPresent(Bool.self, forKey: .restrictedMessaging) ?? false
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        groupAvatar = try c.decodeIfPresent(String.self, forKey: .groupAvatar)
        categories = (try? c.decodeIfPresent([GroupCategory].self, forKey: .categories)) ?? []
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        rules = (try? c.decodeIfPresent([String].self, forKey: .rules)) ?? []
        role = try? c.decodeIfPresent(GroupRole.self, forKey: .role)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
    }

    var effectiveRole: GroupRole { isOwner ? .owner : (role ?? .member) }
}

struct GroupMessage: Decodable, Identifiable, Equatable {
    let id: String
    let communityId: String
    let content: String
    let imageUrl: String?
    let sentAt: Date
    let senderId: String
    let senderName: String
    let senderRole: GroupRole?
    let senderAvatar: String?
    let replyToId: String?
    let replyToContent: String?
    let replyToSenderName: String?
    /// The sender has left the group.
    let isLeft: Bool
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id, communityId, content, imageUrl, sentAt, senderId, senderName, senderRole, senderAvatar,
             replyToId, replyToContent, replyToSenderName, isLeft, isRead
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        communityId = try c.decodeIfPresent(String.self, forKey: .communityId) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        sentAt = c.lenientDate(.sentAt) ?? Date()
        senderId = try c.decodeIfPresent(String.self, forKey: .senderId) ?? ""
        senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        senderRole = try? c.decodeIfPresent(GroupRole.self, forKey: .senderRole)
        senderAvatar = try c.decodeIfPresent(String.self, forKey: .senderAvatar)
        replyToId = try c.decodeIfPresent(String.self, forKey: .replyToId)
        replyToContent = try c.decodeIfPresent(String.self, forKey: .replyToContent)
        replyToSenderName = try c.decodeIfPresent(String.self, forKey: .replyToSenderName)
        isLeft = try c.decodeIfPresent(Bool.self, forKey: .isLeft) ?? (senderRole == nil)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? true
    }

    /// Text shown when quoting this message.
    var previewText: String {
        content.isEmpty && imageUrl?.isEmpty == false ? String(localized: "image_message") : content
    }
}

/// Live event on `/topic/group.{id}.signals`.
struct GroupSignal: Decodable {
    let type: String
    let groupId: String
    let restrictedMessaging: Bool?
}

struct SendGroupMessageRequest: Encodable {
    let content: String
    let imageUrl: String?
    let replyToId: String?
}

// MARK: - Members and requests

struct GroupMember: Decodable, Identifiable, Equatable {
    let userId: String
    let fullName: String
    let avatarImg: String?
    let handle: String
    var role: GroupRole
    let joinedAt: Date?
    let isMe: Bool

    var id: String { userId }

    enum CodingKeys: String, CodingKey { case userId, fullName, avatarImg, handle, role, joinedAt, isMe }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        avatarImg = try c.decodeIfPresent(String.self, forKey: .avatarImg)
        handle = try c.decodeIfPresent(String.self, forKey: .handle) ?? ""
        role = (try? c.decode(GroupRole.self, forKey: .role)) ?? .member
        joinedAt = c.lenientDate(.joinedAt)
        isMe = try c.decodeIfPresent(Bool.self, forKey: .isMe) ?? false
    }
}

struct GroupJoinRequest: Decodable, Identifiable {
    let requestId: String
    let userId: String
    let userName: String
    let userHandle: String
    let userAvatar: String?
    let requestedAt: Date?

    var id: String { requestId }

    enum CodingKeys: String, CodingKey { case requestId, userId, userName, userHandle, userAvatar, requestedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId)
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? ""
        userHandle = try c.decodeIfPresent(String.self, forKey: .userHandle) ?? ""
        userAvatar = try c.decodeIfPresent(String.self, forKey: .userAvatar)
        requestedAt = c.lenientDate(.requestedAt)
    }
}

struct BulkRemoveRequest: Encodable {
    let userIds: [String]
}

struct BulkHandleRequestsRequest: Encodable {
    let requestIds: [String]
    let approve: Bool
}

/// Body of create (`POST community`) and update (`PUT community/{id}`).
struct GroupForm: Encodable {
    var name: String
    var description: String
    var isPrivate: Bool
    var restrictedMessaging: Bool
    var groupAvatar: String?
    var categoryIds: Set<String>
    var tags: Set<String>
    var rules: [String]
    /// Update only.
    var isAvatarRemoved: Bool?
    /// Create only: a community started from a publication's page.
    var publicationId: String?
}

private extension KeyedDecodingContainer {
    /// Instants come as ISO strings, or as epoch seconds when the server's mapper writes numbers.
    func lenientDate(_ key: Key) -> Date? {
        if let text = try? decodeIfPresent(String.self, forKey: key) { return Formatters.date(fromISO: text) }
        if let seconds = try? decodeIfPresent(Double.self, forKey: key) { return Date(timeIntervalSince1970: seconds) }
        return nil
    }
}
