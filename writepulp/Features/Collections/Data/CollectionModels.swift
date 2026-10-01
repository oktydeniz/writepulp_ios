//
//  CollectionModels.swift
//  writepulp
//

import SwiftUI

enum CollectionType: String, Decodable {
    case custom = "DEFAULT"
    case bookmarks = "BOOKMARKS"
    case favorites = "FAVORITES"
    case wishList = "WISH_LIST"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CollectionType(rawValue: raw) ?? .custom
    }

    /// System collections get a localized name; user-made ones keep their own.
    var localizedName: String? {
        switch self {
        case .custom: nil
        case .bookmarks: String(localized: "collection_type_bookmarks")
        case .favorites: String(localized: "collection_type_favorites")
        case .wishList: String(localized: "collection_type_wishlist")
        }
    }
}

/// A collection in the user's lists, someone's profile, or the followed list.
struct UserCollection: Decodable, Identifiable {
    struct Owner: Decodable {
        let uuid: String
        let fullName: String
    }

    struct Preview: Decodable {
        let uuid: String
        let coverImg: String?
    }

    let uuid: String
    let name: String
    let isPrivate: Bool
    let owner: Owner
    let followerCount: Int
    let publications: [Preview]
    let publicationSize: Int
    let type: CollectionType?

    var id: String { uuid }
    var displayName: String { type?.localizedName ?? name }
}

/// `data` of `collections/{id}/detail`.
struct CollectionDetail: Decodable {
    let uuid: String
    let name: String
    let ownerName: String
    let ownerUuid: String
    let publicationSize: Int
    var followerCount: Int
    let isMe: Bool
    var isFollowing: Bool
    let publications: Page<CollectionItem>
}

struct CollectionItem: Decodable, Identifiable {
    let id: String
    let title: String
    let subTitle: String?
    let imageUrl: String?
    let contentType: PublicationType?
    let averageRating: Double?
    let review: Double?
    let estimatedReadTime: Int?

    var rating: Double? { averageRating ?? review }
}

struct CollectionForm: Encodable, Equatable {
    var name: String
    var isPrivate: Bool
}
