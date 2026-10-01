//
//  SearchModels.swift
//  writepulp
//

import SwiftUI

/// One search hit: a publication or a user.
struct SearchResultItem: Decodable, Identifiable {
    enum Kind: String, Decodable {
        case publication = "PUBLICATION"
        case user = "USER"
    }

    let id: String
    let title: String
    let subTitle: String?
    let imageUrl: String?
    let type: Kind
    /// nil for users.
    let contentType: PublicationType?
    let categories: [String]?
    let review: Double?
    let reviewCount: Int?

    var route: MainRoute {
        type == .user ? .profile(userId: id) : .publication(id: id)
    }
}

/// `data` of `search`; mapped to `Page` by the service.
struct SearchResultPage: Decodable {
    let items: [SearchResultItem]
    let totalElements: Int
    let pageNumber: Int
    let isLast: Bool
}

/// The chip row above results. Categories only offer publication types.
enum SearchType: String, CaseIterable, Hashable {
    case all = "ALL"
    case books = "BOOKS"
    case articles = "ARTICLES"
    case magazines = "MAGAZINES"
    case authors = "USER"

    static let publicationTypes: [SearchType] = [.all, .books, .articles, .magazines]

    var title: LocalizedStringKey {
        switch self {
        case .all: "filter_all"
        case .books: "filter_books"
        case .articles: "filter_articles"
        case .magazines: "filter_magazines"
        case .authors: "filter_authors"
        }
    }
}

struct SearchFilters: Equatable {
    enum Sort: String, CaseIterable {
        case relevance = "RELEVANCE"
        case newest = "NEWEST"
        case popular = "POPULAR"

        var title: LocalizedStringKey {
            switch self {
            case .relevance: "sort_relevance"
            case .newest: "sort_newest"
            case .popular: "sort_popular"
            }
        }
    }

    enum ReadingTime: String, CaseIterable {
        case short = "SHORT"
        case medium = "MEDIUM"
        case long = "LONG"

        var title: LocalizedStringKey {
            switch self {
            case .short: "time_short"
            case .medium: "time_medium"
            case .long: "time_long"
            }
        }
    }

    var sort: Sort = .relevance
    /// nil: all, true: completed, false: ongoing.
    var isCompleted: Bool?
    /// 0 means no minimum.
    var minRating = 0
    var readingTime: ReadingTime?
    var language: String?

    var isDefault: Bool { self == SearchFilters() }
}
