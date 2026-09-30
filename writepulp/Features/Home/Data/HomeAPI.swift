//
//  HomeAPI.swift
//  writepulp
//

import Foundation

enum HomeAPI {
    static let pageSize = 20

    /// Guests get the LIMITED feed, so the token is only sent when there is one.
    static func feed() -> Endpoint<HomeFeed> {
        Endpoint(path: "home")
    }

    static func section(key: String, type: PublicationType?, page: Int) -> Endpoint<Page<PublicationFeedCard>> {
        var query = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(pageSize)")]
        if let type { query.append(URLQueryItem(name: "type", value: type.rawValue)) }
        return Endpoint(path: "home/section/\(key)", query: query)
    }

    static func authorsOfTheWeek(page: Int) -> Endpoint<Page<AuthorFeedCard>> {
        Endpoint(
            path: "home/authors-of-week",
            query: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(pageSize)")]
        )
    }

    static func communityPreview(id: String) -> Endpoint<CommunityPreview> {
        Endpoint(path: "community/\(id)/preview")
    }
}
