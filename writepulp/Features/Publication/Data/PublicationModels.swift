//
//  PublicationModels.swift
//  writepulp
//

import SwiftUI

/// `data` of `publications/{id}`.
struct PublicationDetail: Decodable {
    struct Author: Decodable {
        let uuid: String
        let fullName: String
        let avatarImg: String?
    }

    struct Category: Decodable, Hashable {
        let name: String
        let slug: String
    }

    struct Community: Decodable {
        let uuid: String
        let name: String
        let groupAvatar: String?
        let memberCount: Int
    }

    struct CollectionRef: Decodable {
        let uuid: String
    }

    let uuid: String
    let title: String
    let summary: String
    let coverImg: String?
    let type: PublicationType
    let lng: String?
    let author: Author
    let priceCoin: Int
    let sectionCount: Int
    let badges: [ContentBadge]?
    let categories: [Category]
    let isCompleted: Bool?
    let copyright: Copyright?
    let tags: [String]?
    let hasCommunity: Bool
    let community: Community?
    let reviewAverage: Double?
    let totalClicked: Int
    let estimatedReadingTime: Int
    let isOwner: Bool
    let isBookmarked: Bool
    let hasEditRole: Bool
    let libraryItem: LibraryItemRef?
    let lastReadChapterId: String?
    let reviewCount: Int
    let collections: [CollectionRef]
    let isSupportedWithAI: Bool
    let similarPublications: [SimilarPublication]

    struct LibraryItemRef: Decodable {
        let uuid: String
    }

    var hasAccess: Bool { isOwner || libraryItem != nil }
    /// Articles and scripts are a single page: no chapter list, reviews live in the reader.
    var isSinglePage: Bool { type == .article || type == .script }
    var hasChapterList: Bool { sectionCount > 0 && !isSinglePage }
    var showsReviews: Bool { !isSinglePage }
    var isCoverWide: Bool { isSinglePage }
}

struct SimilarPublication: Decodable, Identifiable {
    struct Author: Decodable {
        let fullName: String
    }

    let uuid: String
    let title: String
    let coverImg: String?
    let type: PublicationType
    let author: Author
    let reviewAverage: Double?
    let totalClicked: Int?
    let sectionCount: Int?
    let estimatedReadingTime: Int?

    var id: String { uuid }

    var cardContent: PublicationCardContent {
        PublicationCardContent(
            id: uuid,
            title: title,
            coverImg: coverImg,
            type: type,
            authorName: author.fullName,
            rating: reviewAverage ?? 0,
            views: totalClicked ?? 0,
            sectionCount: sectionCount,
            readTimeMinutes: estimatedReadingTime
        )
    }
}

/// A chapter, or an article inside a magazine issue.
struct PublicationSection: Decodable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let isFree: Bool
    let estimatedReadTime: Int?
    let userProgress: Double?
    let subtitle: String?
    let coverImg: String?
    let heroColor: String?
}

enum ContentBadge: String, Decodable {
    case new = "NEW"
    case featured = "FEATURED"
    case trending = "TRENDING"
    case trendingSearch = "TRENDING_SEARCH"
    case premium = "PREMIUM"
    case mostClicked = "MOST_CLICKED"
    case mostRead = "MOST_READ"
    case topRated = "TOP_RATED"
    case popular = "POPULAR"
    case verified = "VERIFIED"
    case exclusive = "EXCLUSIVE"
    case editorsPick = "EDITORS_PICK"
    case limited = "LIMITED"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ContentBadge(rawValue: raw) ?? .unknown
    }

    var title: LocalizedStringKey? {
        switch self {
        case .new: "badge_new"
        case .featured: "badge_featured"
        case .trending: "badge_trending"
        case .trendingSearch: "badge_trending_search"
        case .premium: "badge_premium"
        case .mostClicked: "badge_most_clicked"
        case .mostRead: "badge_most_read"
        case .topRated: "badge_top_rated"
        case .popular: "badge_popular"
        case .verified: "badge_verified"
        case .exclusive: "badge_exclusive"
        case .editorsPick: "badge_editors_pick"
        case .limited: "badge_limited"
        case .unknown: nil
        }
    }
}

enum Copyright: String, Decodable {
    case allRightsReserved = "ALL_RIGHTS_RESERVED"
    case publicDomain = "PUBLIC_DOMAIN"
    case ccBy = "CC_BY"
    case ccByNc = "CC_BY_NC"
    case ccByNcNd = "CC_BY_NC_ND"
    case ccBySa = "CC_BY_SA"
    case ccByNd = "CC_BY_ND"
    case ccByNcSa = "CC_BY_NC_SA"

    var label: LocalizedStringKey {
        switch self {
        case .allRightsReserved: "copyright_all_rights_reserved_label"
        case .publicDomain: "copyright_public_domain_label"
        case .ccBy: "copyright_cc_by_label"
        case .ccByNc: "copyright_cc_by_nc_label"
        case .ccByNcNd: "copyright_cc_by_nc_nd_label"
        case .ccBySa: "copyright_cc_by_sa_label"
        case .ccByNd: "copyright_cc_by_nd_label"
        case .ccByNcSa: "copyright_cc_by_nc_sa_label"
        }
    }
}

struct Review: Decodable, Identifiable {
    struct User: Decodable {
        let uuid: String
        let fullName: String
        let avatarImg: String?
    }

    let id: String
    let user: User
    let rating: Int
    let comment: String?
    let createdAt: String
}

struct ReviewRequest: Encodable {
    let rating: Int
    let comment: String?
}
