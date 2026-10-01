//
//  SearchResultsModel.swift
//  writepulp
//

import Foundation
import Observation

/// Paged search results for one query/category with type and filter selection.
/// Starting a new search cancels the one in flight, so late responses never overwrite newer ones.
@MainActor
@Observable
final class SearchResultsModel {
    private(set) var type: SearchType = .all
    private(set) var filters = SearchFilters()
    private(set) var results = PagedList<SearchResultItem>()
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private var query = ""
    private let categorySlug: String?
    private let service: SearchService
    private var searchTask: Task<Void, Never>?

    init(service: SearchService, categorySlug: String? = nil) {
        self.service = service
        self.categorySlug = categorySlug
    }

    /// Debounced so typing doesn't fire a request per keystroke.
    func search(query: String, debounce: Bool = false) {
        self.query = query.trimmingCharacters(in: .whitespaces)
        restart(debounce: debounce)
    }

    func setType(_ type: SearchType) {
        guard type != self.type else { return }
        self.type = type
        restart(debounce: false)
    }

    func applyFilters(_ filters: SearchFilters) {
        self.filters = filters
        restart(debounce: false)
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        type = .all
        filters = SearchFilters()
        results = PagedList()
        isLoading = false
        errorMessage = nil
    }

    func refresh() async {
        restart(debounce: false)
        await searchTask?.value
    }

    func loadMore() async {
        guard results.hasLoaded, results.hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetch(page: results.nextPage)
            results.apply(page, replacing: false)
        } catch {
            // The next scroll retries.
        }
    }

    private func restart(debounce: Bool) {
        searchTask?.cancel()
        // A plain search needs text; a category lists everything in it.
        guard !query.isEmpty || categorySlug != nil else {
            results = PagedList()
            isLoading = false
            return
        }
        isLoading = true
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled else { return }
            do {
                let page = try await fetch(page: 0)
                guard !Task.isCancelled else { return }
                results.apply(page, replacing: true)
                errorMessage = nil
            } catch APIError.cancelled {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func fetch(page: Int) async throws -> Page<SearchResultItem> {
        try await service.search(query: query, type: type, filters: filters, categorySlug: categorySlug, page: page)
    }
}
