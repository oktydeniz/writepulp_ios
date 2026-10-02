//
//  ArticleReaderViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Single-page reader for articles and scripts.
@MainActor
@Observable
final class ArticleReaderViewModel {
    let publicationId: String
    private(set) var article: ReaderArticle?
    private(set) var document = EditorDocument()
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isSaved = false
    private(set) var reactions: ReactionsViewModel?
    private(set) var reviews: ReviewsViewModel?
    var toastMessage: String?

    private let service: ReaderService
    private let session: ReadingSessionTracker
    @ObservationIgnored private var throttle = ProgressThrottle()

    init(publicationId: String, service: ReaderService) {
        self.publicationId = publicationId
        self.service = service
        session = ReadingSessionTracker(service: service)
    }

    var isSignedIn: Bool { service.isSignedIn }

    func start() async {
        guard article == nil else { return }
        await service.syncPendingProgress()
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await service.article(publicationId: publicationId)
            throttle.reset(to: loaded.userProgress)
            article = loaded
            document = EditorDocument.parse(loaded.body)
            isSaved = loaded.isBookmarked
            errorMessage = nil
            reactions = ReactionsViewModel(sectionId: loaded.id, initial: loaded.reaction, service: service)
            let service = service
            reviews = ReviewsViewModel(
                source: service.sectionReviewsSource(sectionId: loaded.id),
                session: { (service.isSignedIn, service.currentUserId) }
            )
            session.update(publicationId: publicationId, sectionId: loaded.id, enabled: loaded.earnsCoins)
            if !loaded.isOwner {
                Task { await service.incrementView(sectionId: loaded.id) }
            }
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBookmark() async {
        guard let article else { return }
        let saved = !isSaved
        isSaved = saved
        do {
            try await service.toggleBookmark(publicationId: article.publication.uuid)
        } catch {
            isSaved = !saved
            toastMessage = error.localizedDescription
        }
    }

    func recordProgress(_ percent: Double) {
        guard let article, !article.isOwner, throttle.shouldSend(percent) else { return }
        let service = service
        Task { await service.recordProgress(sectionId: article.id, percent: percent) }
    }

    func pauseSession() { session.pause() }
    func resumeSession() { session.resume() }
}

/// Reaction counts of a section and the viewer's own pick, updated optimistically.
@MainActor
@Observable
final class ReactionsViewModel {
    let sectionId: String
    private(set) var counts: [ReactionType: Int] = [:]
    private(set) var mine: ReactionType?
    private(set) var isSubmitting = false
    private var hasLoaded = false

    private let service: ReaderService

    init(sectionId: String, initial: ReactionType?, service: ReaderService) {
        self.sectionId = sectionId
        self.mine = initial
        self.service = service
    }

    var total: Int { counts.values.reduce(0, +) }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func pick(_ type: ReactionType) async {
        guard !isSubmitting else { return }
        let previous = mine
        let previousCounts = counts
        if previous == type {
            counts[type] = max(0, (counts[type] ?? 0) - 1)
            mine = nil
        } else {
            if let previous { counts[previous] = max(0, (counts[previous] ?? 0) - 1) }
            counts[type, default: 0] += 1
            mine = type
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if previous != nil {
                try await service.removeReaction(sectionId: sectionId)
            }
            if previous != type {
                try await service.addReaction(sectionId: sectionId, type)
            }
            await refresh()
        } catch {
            mine = previous
            counts = previousCounts
        }
    }

    private func refresh() async {
        guard let result = try? await service.reactions(sectionId: sectionId) else { return }
        counts = result.counts
        if service.isSignedIn { mine = result.mine }
    }
}
