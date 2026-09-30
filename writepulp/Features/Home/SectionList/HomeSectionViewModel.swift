//
//  HomeSectionViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// "See all" for a home section (paged publications with a type filter) or for authors of the week.
@MainActor
@Observable
final class HomeSectionViewModel {
    enum Source {
        case section(key: String)
        case authorsOfTheWeek
    }

    let source: Source
    let title: String
    private(set) var typeFilter: PublicationType?
    private(set) var publications: [PublicationFeedCard] = []
    private(set) var authors: [AuthorFeedCard] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private var nextPage = 0
    private var isLastPage = false
    private let service: HomeService

    init(source: Source, title: String, typeFilter: PublicationType?, service: HomeService) {
        self.source = source
        self.title = title
        self.typeFilter = typeFilter
        self.service = service
    }

    var isAuthors: Bool {
        if case .authorsOfTheWeek = source { return true }
        return false
    }

    var isEmpty: Bool { publications.isEmpty && authors.isEmpty }

    func loadFirstPage() async {
        nextPage = 0
        isLastPage = false
        isLoading = true
        defer { isLoading = false }
        await loadPage(replacing: true)
    }

    /// Called as the last rows appear.
    func loadMore() async {
        guard !isLastPage, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadPage(replacing: false)
    }

    func setTypeFilter(_ type: PublicationType?) async {
        guard !isAuthors, type != typeFilter else { return }
        typeFilter = type
        publications = []
        await loadFirstPage()
    }

    private func loadPage(replacing: Bool) async {
        do {
            switch source {
            case .section(let key):
                let page = try await service.section(key: key, type: typeFilter, page: nextPage)
                publications = replacing ? page.content : publications + page.content
                isLastPage = page.last
            case .authorsOfTheWeek:
                let page = try await service.authorsOfTheWeek(page: nextPage)
                authors = replacing ? page.content : authors + page.content
                isLastPage = page.last
            }
            nextPage += 1
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
