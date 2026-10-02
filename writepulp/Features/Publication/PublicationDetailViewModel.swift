//
//  PublicationDetailViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class PublicationDetailViewModel {
    enum Tab: Hashable {
        case overview, chapters, reviews
    }

    let publicationId: String
    var tab: Tab = .overview
    private(set) var publication: PublicationDetail?
    private(set) var sections = PagedList<PublicationSection>()
    private(set) var isLoading = false
    private(set) var isLoadingSections = false
    private(set) var isAddingToLibrary = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    let reviews: ReviewsViewModel
    private let service: PublicationService
    private var hasCountedView = false

    init(publicationId: String, service: PublicationService) {
        self.publicationId = publicationId
        self.service = service
        reviews = ReviewsViewModel(
            source: PublicationReviewsSource(publicationId: publicationId, service: service),
            session: { (service.isSignedIn, service.currentUserId) }
        )
    }

    var isSignedIn: Bool { service.isSignedIn }

    var tabs: [Tab] {
        guard let publication else { return [.overview] }
        var tabs: [Tab] = [.overview]
        if publication.hasChapterList { tabs.append(.chapters) }
        if publication.showsReviews { tabs.append(.reviews) }
        return tabs
    }

    /// Where "Read" starts: the last read chapter, else the first one.
    var startChapterId: String? {
        publication?.lastReadChapterId ?? sections.items.first?.id
    }

    func load() async {
        isLoading = publication == nil
        defer { isLoading = false }
        do {
            let detail = try await service.detail(id: publicationId)
            publication = detail
            errorMessage = nil
            if !tabs.contains(tab) { tab = .overview }
            if !hasCountedView, !detail.isOwner, !detail.hasEditRole {
                hasCountedView = true
                await service.incrementView(id: publicationId)
            }
            if detail.sectionCount > 0 { await loadSections(replacing: true) }
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreSections() async {
        guard sections.hasMore, !isLoadingSections, sections.hasLoaded else { return }
        await loadSections(replacing: false)
    }

    private func loadSections(replacing: Bool) async {
        isLoadingSections = true
        defer { isLoadingSections = false }
        do {
            let page = try await service.sections(publicationId: publicationId, page: replacing ? 0 : sections.nextPage)
            sections.apply(page, replacing: replacing)
        } catch {
            // The chapter list stays as it was; a refresh retries.
        }
    }

    func addToLibrary() async {
        guard let publication, !isAddingToLibrary else { return }
        isAddingToLibrary = true
        defer { isAddingToLibrary = false }
        do {
            try await service.addToLibrary(publication)
            toastMessage = String(localized: "content_detail_added_to_library")
            await load()
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}
