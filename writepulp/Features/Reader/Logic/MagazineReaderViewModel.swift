//
//  MagazineReaderViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Swipeable magazine issue: one page per section, loaded as it's reached.
@MainActor
@Observable
final class MagazineReaderViewModel {
    struct LoadedPage {
        let content: ReaderChapter
        let document: EditorDocument
    }

    let publicationId: String
    private(set) var chaptersList: ReaderChaptersList?
    private(set) var pages: [String: LoadedPage] = [:]
    private(set) var failedPages: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Set once the starting page is known; the pager binds to it.
    var currentIndex = 0 {
        didSet { if currentIndex != oldValue { pageChanged() } }
    }

    private let service: ReaderService
    private let session: ReadingSessionTracker
    private let initialChapterId: String?
    @ObservationIgnored private var throttle = ProgressThrottle()
    private var loadingIds: Set<String> = []
    private var viewedIds: Set<String> = []

    init(publicationId: String, chapterId: String?, service: ReaderService) {
        self.publicationId = publicationId
        self.initialChapterId = chapterId
        self.service = service
        session = ReadingSessionTracker(service: service)
    }

    var chapters: [ReaderChapterSummary] { chaptersList?.ordered ?? [] }
    var currentSummary: ReaderChapterSummary? { chapters.indices.contains(currentIndex) ? chapters[currentIndex] : nil }

    func canOpen(_ summary: ReaderChapterSummary) -> Bool {
        chaptersList?.canAccess(summary) ?? true
    }

    func start() async {
        guard chaptersList == nil else { return }
        await service.syncPendingProgress()
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await service.chaptersList(publicationId: publicationId)
            let ordered = list.ordered
            // An explicit page wins; otherwise open where the reader left off.
            let resolved = try? await service.chapter(publicationId: publicationId, chapterId: initialChapterId)
            let index = resolved.flatMap { page in ordered.firstIndex { $0.id == page.id } } ?? 0
            if let resolved, ordered.contains(where: { $0.id == resolved.id }) {
                store(resolved)
            }
            chaptersList = list
            errorMessage = nil
            if currentIndex == index {
                pageChanged()
            } else {
                currentIndex = index
            }
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goTo(_ index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentIndex = index
    }

    func select(_ summary: ReaderChapterSummary) {
        if let index = chapters.firstIndex(where: { $0.id == summary.id }) { goTo(index) }
    }

    /// Loads a page that's about to be shown (neighbors are preloaded for smooth swiping).
    func loadPageIfNeeded(_ summary: ReaderChapterSummary) async {
        guard canOpen(summary), pages[summary.id] == nil, !loadingIds.contains(summary.id) else { return }
        loadingIds.insert(summary.id)
        defer { loadingIds.remove(summary.id) }
        failedPages.remove(summary.id)
        do {
            let page = try await service.chapter(publicationId: publicationId, chapterId: summary.id)
            store(page)
        } catch APIError.cancelled {
        } catch {
            failedPages.insert(summary.id)
        }
    }

    func recordProgress(_ percent: Double, pageId: String) {
        guard pageId == currentSummary?.id, let page = pages[pageId]?.content,
              !page.isOwner, page.isAccessible, throttle.shouldSend(percent) else { return }
        let service = service
        Task { await service.recordProgress(publicationId: publicationId, sectionId: pageId, percent: percent) }
    }

    func pauseSession() { session.pause() }
    func resumeSession() { session.resume() }

    // MARK: - Private

    private func store(_ page: ReaderChapter) {
        pages[page.id] = LoadedPage(content: page, document: EditorDocument.parse(page.body))
        if page.id == currentSummary?.id { throttle.reset(to: page.userProgress) }
    }

    /// Views count once per page actually shown, not for preloaded neighbors.
    private func countView(_ id: String) {
        guard let page = pages[id]?.content, !page.isOwner, !viewedIds.contains(id) else { return }
        viewedIds.insert(id)
        let service = service
        Task { await service.incrementView(sectionId: id) }
    }

    private func pageChanged() {
        guard let summary = currentSummary, let list = chaptersList else { return }
        throttle.reset(to: pages[summary.id]?.content.userProgress ?? summary.userProgress)
        session.update(publicationId: publicationId, sectionId: summary.id, enabled: list.earnsCoins)
        Task {
            await loadPageIfNeeded(summary)
            if currentSummary?.id == summary.id { countView(summary.id) }
            for neighbor in [currentIndex - 1, currentIndex + 1] where chapters.indices.contains(neighbor) {
                await loadPageIfNeeded(chapters[neighbor])
            }
        }
    }
}
