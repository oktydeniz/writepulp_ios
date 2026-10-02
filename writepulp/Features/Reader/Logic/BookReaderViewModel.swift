//
//  BookReaderViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Chapter-by-chapter reader for books, open books and scripts with chapters.
@MainActor
@Observable
final class BookReaderViewModel {
    let publicationId: String
    private(set) var chaptersList: ReaderChaptersList?
    private(set) var chapter: ReaderChapter?
    private(set) var document = EditorDocument()
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: ReaderService
    private let session: ReadingSessionTracker
    private let initialChapterId: String?
    @ObservationIgnored private var throttle = ProgressThrottle()
    private var loadTask: Task<Void, Never>?

    init(publicationId: String, chapterId: String?, service: ReaderService) {
        self.publicationId = publicationId
        self.initialChapterId = chapterId
        self.service = service
        session = ReadingSessionTracker(service: service)
    }

    var chapters: [ReaderChapterSummary] { chaptersList?.ordered ?? [] }

    var chapterNumber: Int {
        guard let chapter else { return 0 }
        return (chapters.firstIndex { $0.id == chapter.id } ?? 0) + 1
    }

    var hasPrevious: Bool { neighbor(-1) != nil }
    var hasNext: Bool { neighbor(1) != nil }

    /// While the list hasn't loaded, every row counts as open; the server is the judge.
    func canOpen(_ summary: ReaderChapterSummary) -> Bool {
        chaptersList?.canAccess(summary) ?? true
    }

    func start() async {
        guard chapter == nil, chaptersList == nil else { return }
        await service.syncPendingProgress()
        async let list: Void = loadChaptersList()
        async let content: Void = loadChapter(initialChapterId)
        _ = await (list, content)
    }

    func select(_ summary: ReaderChapterSummary) {
        guard canOpen(summary), summary.id != chapter?.id else { return }
        open(summary.id)
    }

    func goToNext() {
        if let next = neighbor(1) { open(next.id) }
    }

    func goToPrevious() {
        if let previous = neighbor(-1) { open(previous.id) }
    }

    func retry() async {
        errorMessage = nil
        if chaptersList == nil { await loadChaptersList() }
        await loadChapter(chapter?.id ?? initialChapterId)
    }

    func recordProgress(_ percent: Double) {
        guard let chapter, !chapter.isOwner, chapter.isAccessible, throttle.shouldSend(percent) else { return }
        let service = service
        Task { await service.recordProgress(sectionId: chapter.id, percent: percent) }
    }

    func pauseSession() { session.pause() }
    func resumeSession() { session.resume() }

    // MARK: - Loading

    private func open(_ chapterId: String) {
        loadTask?.cancel()
        loadTask = Task { await loadChapter(chapterId) }
    }

    private func loadChaptersList() async {
        do {
            chaptersList = try await service.chaptersList(publicationId: publicationId)
        } catch APIError.cancelled {
        } catch {
            if chapter == nil { errorMessage = error.localizedDescription }
        }
    }

    private func loadChapter(_ chapterId: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await service.chapter(publicationId: publicationId, chapterId: chapterId)
            if Task.isCancelled { return }
            apply(loaded)
        } catch APIError.cancelled {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func apply(_ loaded: ReaderChapter) {
        throttle.reset(to: loaded.userProgress)
        chapter = loaded
        document = EditorDocument.parse(loaded.body)
        errorMessage = nil
        session.update(publicationId: publicationId, sectionId: loaded.id, enabled: loaded.earnsCoins && loaded.isAccessible)
        if !loaded.isOwner {
            let service = service
            Task { await service.incrementView(sectionId: loaded.id) }
        }
    }

    /// The nearest chapter in that direction the reader can open; locked ones are skipped.
    private func neighbor(_ direction: Int) -> ReaderChapterSummary? {
        guard let list = chaptersList, let current = chapter else { return nil }
        let ordered = list.ordered
        guard var index = ordered.firstIndex(where: { $0.id == current.id }) else { return nil }
        index += direction
        while ordered.indices.contains(index) {
            if list.canAccess(ordered[index]) { return ordered[index] }
            index += direction
        }
        return nil
    }
}
