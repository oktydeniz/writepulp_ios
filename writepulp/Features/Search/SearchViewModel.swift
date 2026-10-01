//
//  SearchViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Search tab: category groups while the field is empty, results while typing.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    let results: SearchResultsModel
    private(set) var categories: [CategoryGroup] = []
    private(set) var isLoadingCategories = false
    private(set) var categoriesError: String?

    private let service: SearchService

    init(service: SearchService) {
        self.service = service
        results = SearchResultsModel(service: service)
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categories = try await service.categoryGroups()
            categoriesError = nil
        } catch APIError.cancelled {
        } catch {
            categoriesError = error.localizedDescription
        }
    }

    func queryChanged() {
        if isSearching {
            results.search(query: query, debounce: true)
        } else {
            results.reset()
        }
    }

    func clear() {
        query = ""
        results.reset()
    }
}
