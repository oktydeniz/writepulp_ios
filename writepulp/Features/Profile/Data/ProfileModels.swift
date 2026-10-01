//
//  ProfileModels.swift
//  writepulp
//

import SwiftUI

/// The viewer's own follow request toward another user.
enum FollowStatus: String, Decodable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case none = "NONE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FollowStatus(rawValue: raw) ?? .none
    }
}

/// Follow button state derived from `isFollowing` + `followStatus`.
enum FollowState {
    case notFollowing
    case requested
    case following

    init(isFollowing: Bool, status: FollowStatus?) {
        if status == .pending {
            self = .requested
        } else if isFollowing || status == .accepted {
            self = .following
        } else {
            self = .notFollowing
        }
    }

    /// What a successful toggle leads to: private accounts get a request instead of a follow.
    func toggled(isPrivateAccount: Bool) -> FollowState {
        switch self {
        case .following, .requested: .notFollowing
        case .notFollowing: isPrivateAccount ? .requested : .following
        }
    }

    var isFollowing: Bool { self == .following }

    var status: FollowStatus {
        switch self {
        case .notFollowing: .none
        case .requested: .pending
        case .following: .accepted
        }
    }
}

struct SocialLinks: Codable, Equatable {
    var website: String?
    var instagram: String?
    var xLink: String?
    var linkedin: String?
    var github: String?
    var facebook: String?
    var tiktok: String?
    var telegram: String?
    var discord: String?

    var isEmpty: Bool {
        SocialPlatform.allCases.allSatisfy { self[keyPath: $0.keyPath]?.isEmpty ?? true }
    }
}

enum SocialPlatform: CaseIterable, Identifiable {
    case website, instagram, tiktok, x, github, linkedin, facebook, telegram, discord

    var id: Self { self }

    var keyPath: WritableKeyPath<SocialLinks, String?> {
        switch self {
        case .website: \.website
        case .instagram: \.instagram
        case .tiktok: \.tiktok
        case .x: \.xLink
        case .github: \.github
        case .linkedin: \.linkedin
        case .facebook: \.facebook
        case .telegram: \.telegram
        case .discord: \.discord
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .website: "website"
        case .instagram: "instagram"
        case .tiktok: "tiktok"
        case .x: "x"
        case .github: "github"
        case .linkedin: "linkedin"
        case .facebook: "facebook"
        case .telegram: "telegram"
        case .discord: "discord"
        }
    }

    var icon: Image {
        switch self {
        case .website: Image(systemName: "globe")
        case .instagram: Image("Social_instagram")
        case .tiktok: Image("Social_tiktok")
        case .x: Image("Social_x")
        case .github: Image("Social_github")
        case .linkedin: Image("Social_linkedin")
        case .facebook: Image("Social_facebook")
        case .telegram: Image("Social_telegram")
        case .discord: Image("Social_discord")
        }
    }

    /// Users often save links without a scheme.
    static func url(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
    }
}

/// `data` of `profile/me` and `profile/{uuid}`.
struct UserProfile: Decodable {
    let uuid: String
    let fullName: String
    let avatarImg: String?
    let about: String?
    let handle: String
    let location: String?
    var followerCount: Int
    let followingCount: Int
    let createdAt: String?
    let isPrivateAccount: Bool
    let isMe: Bool
    private(set) var isFollowing: Bool
    private(set) var followStatus: FollowStatus?
    let socialLinks: SocialLinks?
    let worksCount: Int
    let badge: String?
    let approvedAccount: Bool

    var followState: FollowState { FollowState(isFollowing: isFollowing, status: followStatus) }

    /// Private accounts hide their content until the viewer follows them.
    var isContentVisible: Bool { isMe || !isPrivateAccount || isFollowing }

    mutating func applyFollowToggle() {
        let previous = followState
        let next = previous.toggled(isPrivateAccount: isPrivateAccount)
        isFollowing = next.isFollowing
        followStatus = next.status
        if previous == .following { followerCount = max(0, followerCount - 1) }
        if next == .following { followerCount += 1 }
    }

    var badgeEmoji: String? {
        guard let badge, !badge.isEmpty else { return nil }
        let emojis = [
            "FIRST_100": "🥇", "FIRST_500": "🥈", "FIRST_1000": "🥉",
            "FIRST_5000": "🧭", "FIRST_10000": "🐾", "PIONEER": "🚀",
        ]
        return emojis[badge] ?? badge
    }
}

/// A row of a followers / following list.
struct FollowUser: Decodable, Identifiable {
    let uuid: String
    let fullName: String
    let avatarImg: String?
    let handle: String
    private(set) var isFollowing: Bool
    private(set) var isFollower: Bool
    private(set) var followStatus: FollowStatus?
    let isPrivateAccount: Bool
    let isMe: Bool
    /// This user asked to follow the viewer and waits for approval.
    private(set) var hasPendingFollowRequest: Bool

    var id: String { uuid }
    var followState: FollowState { FollowState(isFollowing: isFollowing, status: followStatus) }

    mutating func applyFollowToggle() {
        let next = followState.toggled(isPrivateAccount: isPrivateAccount)
        isFollowing = next.isFollowing
        followStatus = next.status
    }

    mutating func applyRequestResponse(approved: Bool) {
        hasPendingFollowRequest = false
        if approved { isFollower = true }
    }
}

enum FollowListKind: Hashable, CaseIterable {
    case followers
    case following

    var title: LocalizedStringKey {
        switch self {
        case .followers: "followers"
        case .following: "following"
        }
    }
}

/// `data` of `profile/edit`; also the edit form's draft.
struct EditableProfile: Decodable, Equatable {
    let uuid: String
    var fullName: String
    var avatarImg: String?
    var email: String
    var about: String?
    var handle: String
    var location: String?
    var birthDate: String?
    let isEmailVerified: Bool
    var socialLinks: SocialLinks?
}

struct ProfileUpdateRequest: Encodable {
    let fullName: String
    let birthDate: String?
    let avatarImg: String?
    let location: String?
    let about: String?
    let handle: String
    let email: String
    let socialLinks: SocialLinks
    let isAvatarRemoved: Bool
}

struct ProfileUpdateResult: Decodable {
    let userId: String
    let isEmailVerified: Bool
}
