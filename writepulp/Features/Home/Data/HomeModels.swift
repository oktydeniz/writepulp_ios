//
//  HomeModels.swift
//  writepulp
//

import Foundation

struct HomeFeed: Decodable {
    enum Mode: String, Decodable {
        case full = "FULL"
        /// Guests: fewer sections plus a sign-in banner.
        case limited = "LIMITED"
    }

    let mode: Mode
    let typeFilter: PublicationType?
    let continueReading: [PublicationFeedCard]
    let sections: [HomeFeedSection]
    let authorsOfTheWeek: [AuthorFeedCard]
    let communityGroupIds: [String]
}

struct HomeFeedSection: Decodable, Identifiable {
    let key: String
    let title: String
    let items: [PublicationFeedCard]

    var id: String { key }

    /// The backend localizes titles; this only covers a raw message key leaking through,
    /// using the `home_section_<key>` strings.
    var displayTitle: String {
        guard title.isEmpty || title == key || title.hasPrefix("home.") else { return title }
        let normalized = key.lowercased().replacingOccurrences(of: #"[.\s-]+"#, with: "_", options: .regularExpression)
        let stringKey = "home_section_" + normalized
        let localized = Bundle.main.localizedString(forKey: stringKey, value: nil, table: nil)
        return localized == stringKey ? title : localized
    }
}

struct PublicationFeedCard: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let coverImg: String?
    let type: PublicationType
    let authorName: String
    let authorId: String
    let reviewAverage: Double?
    let totalClicked: Int?
    let estimatedReadTime: Int?

    var cardContent: PublicationCardContent {
        PublicationCardContent(
            id: id,
            title: title,
            coverImg: coverImg,
            type: type,
            authorName: authorName,
            rating: reviewAverage ?? 0,
            views: totalClicked ?? 0,
            readTimeMinutes: estimatedReadTime
        )
    }
}

struct AuthorFeedCard: Decodable, Identifiable, Hashable {
    let id: String
    let fullName: String
    let handle: String
    let avatarImg: String?
    let publicationCount: Int?
}

/// `data` of `community/{id}/preview`, the fields the home strip needs.
struct CommunityPreview: Decodable, Identifiable, Hashable {
    let uuid: String
    let name: String
    let groupAvatar: String?
    let memberCount: Int?

    var id: String { uuid }
}
