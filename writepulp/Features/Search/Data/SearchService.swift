//
//  SearchService.swift
//  writepulp
//

import Foundation

@MainActor
final class SearchService {
    private let api: APIClient
    private let session: SessionStore

    nonisolated init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func categoryGroups() async throws -> [CategoryGroup] {
        try await api.send(CategoryAPI.grouped())
    }

    /// The signed-in user is left out of user results.
    func search(
        query: String,
        type: SearchType,
        filters: SearchFilters,
        categorySlug: String? = nil,
        page: Int
    ) async throws -> Page<SearchResultItem> {
        let result = try await api.send(SearchAPI.search(
            query: query, type: type, filters: filters, categorySlug: categorySlug, page: page
        ))
        let items = result.items.filter { !($0.type == .user && $0.id == session.userId) }
        return Page(
            content: items,
            number: result.pageNumber,
            last: result.isLast,
            totalElements: result.totalElements - (result.items.count - items.count)
        )
    }
}
