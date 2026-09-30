//
//  HomeService.swift
//  writepulp
//

import Foundation

@MainActor
final class HomeService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    func feed() async throws -> HomeFeed {
        try await api.send(HomeAPI.feed())
    }

    func section(key: String, type: PublicationType?, page: Int) async throws -> Page<PublicationFeedCard> {
        try await api.send(HomeAPI.section(key: key, type: type, page: page))
    }

    func authorsOfTheWeek(page: Int) async throws -> Page<AuthorFeedCard> {
        try await api.send(HomeAPI.authorsOfTheWeek(page: page))
    }

    /// Fetched in parallel; ones that fail are left out, in the original order.
    func communityPreviews(ids: [String]) async -> [CommunityPreview] {
        let api = api
        let results = await withTaskGroup(of: (Int, CommunityPreview?).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { (index, try? await api.send(HomeAPI.communityPreview(id: id))) }
            }
            var collected: [(Int, CommunityPreview?)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        return results.sorted { $0.0 < $1.0 }.compactMap(\.1)
    }
}
