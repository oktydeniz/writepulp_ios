//
//  ReaderService.swift
//  writepulp
//

import Foundation

enum ReaderAPI {
    static func chaptersList(publicationId: String) -> Endpoint<ReaderChaptersList> {
        Endpoint(path: "sections/reader/\(publicationId)/chapters-list")
    }

    static func chapter(publicationId: String, chapterId: String) -> Endpoint<ReaderChapter> {
        Endpoint(path: "sections/reader/\(publicationId)/chapters/\(chapterId)")
    }

    /// The chapter the user last read, else the first one.
    static func currentChapter(publicationId: String) -> Endpoint<ReaderChapter> {
        Endpoint(path: "sections/reader/\(publicationId)/current-chapter")
    }

    static func article(publicationId: String) -> Endpoint<ReaderArticle> {
        Endpoint(path: "sections/\(publicationId)/article")
    }

    static func incrementView(sectionId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/\(sectionId)/view", method: .post)
    }

    /// `readAt` (ISO-8601) is only sent when replaying progress recorded offline.
    static func progress(sectionId: String, percent: Double, readAt: String?) -> Endpoint<EmptyResponse> {
        var query = [URLQueryItem(name: "percent", value: String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), percent))]
        if let readAt { query.append(URLQueryItem(name: "readAt", value: readAt)) }
        return Endpoint(path: "sections/\(sectionId)/progress", method: .post, query: query)
    }

    static func startSession(publicationId: String, sectionId: String) -> Endpoint<ReadingSession> {
        Endpoint(
            path: "reading/start/\(publicationId)/handle",
            method: .post,
            query: [
                URLQueryItem(name: "sectionId", value: sectionId),
                URLQueryItem(name: "deviceType", value: "MOBILE"),
            ]
        )
    }

    static func heartbeat(sessionId: String, _ request: SessionHeartbeatRequest) -> Endpoint<ReadingSession> {
        Endpoint(path: "reading/heartbeat/\(sessionId)", method: .put, body: request)
    }

    static func stopSession(sessionId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "reading/stop/\(sessionId)", method: .post)
    }

    static func toggleBookmark(publicationId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(publicationId)/toggle-bookmark", method: .patch)
    }

    // MARK: Reactions

    static func reactions(sectionId: String) -> Endpoint<[SectionReaction]> {
        Endpoint(path: "reactions/sections/\(sectionId)")
    }

    static func reactionCounts(sectionId: String) -> Endpoint<[String: Int]> {
        Endpoint(path: "reactions/sections/\(sectionId)/counts")
    }

    static func addReaction(sectionId: String, _ type: ReactionType) -> Endpoint<EmptyResponse> {
        Endpoint(path: "reactions/sections/\(sectionId)", method: .post, body: AddReactionRequest(type: type))
    }

    static func removeReaction(sectionId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "reactions/sections/\(sectionId)", method: .delete)
    }

    // MARK: Section reviews

    static func reviews(sectionId: String) -> Endpoint<[Review]> {
        Endpoint(path: "sections/\(sectionId)/reviews")
    }

    static func addReview(sectionId: String, _ request: ReviewRequest) -> Endpoint<Review> {
        Endpoint(path: "sections/\(sectionId)/reviews", method: .post, body: request)
    }

    static func updateReview(sectionId: String, reviewId: String, _ request: ReviewRequest) -> Endpoint<Review> {
        Endpoint(path: "sections/\(sectionId)/reviews/\(reviewId)", method: .put, body: request)
    }

    static func deleteReview(sectionId: String, reviewId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/\(sectionId)/reviews/\(reviewId)", method: .delete)
    }
}

@MainActor
final class ReaderService {
    private let api: APIClient
    private let session: SessionStore
    private let pendingProgress: PendingProgressStore
    private let offline: OfflineReaderSource?

    nonisolated init(
        api: APIClient,
        session: SessionStore,
        offline: OfflineReaderSource? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.session = session
        self.offline = offline
        pendingProgress = PendingProgressStore(defaults: defaults)
    }

    var isSignedIn: Bool { session.isLoggedIn }
    var currentUserId: String? { session.userId }

    // Content falls back to the downloaded copy when the server can't be reached.

    func chaptersList(publicationId: String) async throws -> ReaderChaptersList {
        try await withOfflineFallback {
            try await api.send(ReaderAPI.chaptersList(publicationId: publicationId))
        } offline: { source in
            await source.chaptersList(publicationId: publicationId)
        }
    }

    /// nil chapter: where the user left off.
    func chapter(publicationId: String, chapterId: String?) async throws -> ReaderChapter {
        try await withOfflineFallback {
            if let chapterId {
                return try await api.send(ReaderAPI.chapter(publicationId: publicationId, chapterId: chapterId))
            }
            return try await api.send(ReaderAPI.currentChapter(publicationId: publicationId))
        } offline: { source in
            guard let local = await source.chapter(publicationId: publicationId, chapterId: chapterId) else { return nil }
            await markOpenedOffline(publicationId: publicationId, sectionId: local.id)
            return local
        }
    }

    func article(publicationId: String) async throws -> ReaderArticle {
        try await withOfflineFallback {
            try await api.send(ReaderAPI.article(publicationId: publicationId))
        } offline: { source in
            guard let local = await source.article(publicationId: publicationId) else { return nil }
            await markOpenedOffline(publicationId: publicationId, sectionId: local.id)
            return local
        }
    }

    private func withOfflineFallback<T>(
        _ online: () async throws -> T,
        offline: (OfflineReaderSource) async -> T?
    ) async throws -> T {
        do {
            return try await online()
        } catch let error as APIError where error.isRetryable {
            if let source = self.offline, let local = await offline(source) { return local }
            throw error
        }
    }

    /// Offline, the server never learns which section was opened; a 0% entry only stamps the
    /// read time (progress is kept at its max) so "continue reading" follows it once synced.
    private func markOpenedOffline(publicationId: String, sectionId: String) async {
        await recordProgress(publicationId: publicationId, sectionId: sectionId, percent: 0)
    }

    func incrementView(sectionId: String) async {
        _ = try? await api.send(ReaderAPI.incrementView(sectionId: sectionId))
    }

    func toggleBookmark(publicationId: String) async throws {
        _ = try await api.send(ReaderAPI.toggleBookmark(publicationId: publicationId))
    }

    // MARK: Progress

    /// Sends progress; when the server can't be reached it's kept and replayed later with its original time.
    func recordProgress(publicationId: String, sectionId: String, percent: Double) async {
        guard isSignedIn, let userId = currentUserId else { return }
        let percent = min(max(percent, 0), 100)
        await offline?.recordProgress(publicationId: publicationId, sectionId: sectionId, percent: percent)
        do {
            _ = try await api.send(ReaderAPI.progress(sectionId: sectionId, percent: percent, readAt: nil))
            pendingProgress.remove(sectionId: sectionId, ifAtMost: percent)
            await syncPendingProgress()
        } catch let error as APIError where error.isRetryable {
            pendingProgress.store(sectionId: sectionId, percent: percent, userId: userId)
        } catch {
            // Rejected (e.g. no access anymore): retrying won't change that.
        }
    }

    func syncPendingProgress() async {
        guard isSignedIn, let userId = currentUserId else { return }
        for entry in pendingProgress.entries(for: userId) {
            do {
                _ = try await api.send(ReaderAPI.progress(
                    sectionId: entry.sectionId,
                    percent: entry.percent,
                    readAt: ISO8601DateFormatter().string(from: entry.readAt)
                ))
                pendingProgress.remove(sectionId: entry.sectionId, ifAtMost: entry.percent)
            } catch let error as APIError where error.isRetryable {
                return
            } catch {
                pendingProgress.remove(sectionId: entry.sectionId, ifAtMost: entry.percent)
            }
        }
    }

    // MARK: Reading sessions

    func startSession(publicationId: String, sectionId: String) async throws -> ReadingSession {
        try await api.send(ReaderAPI.startSession(publicationId: publicationId, sectionId: sectionId))
    }

    func heartbeat(sessionId: String, sectionId: String, elapsedSeconds: Int) async throws -> ReadingSession {
        try await api.send(ReaderAPI.heartbeat(
            sessionId: sessionId,
            SessionHeartbeatRequest(sectionId: sectionId, elapsedSeconds: elapsedSeconds)
        ))
    }

    func stopSession(sessionId: String) async {
        _ = try? await api.send(ReaderAPI.stopSession(sessionId: sessionId))
    }

    // MARK: Reactions

    /// Counts per type and the viewer's own reaction.
    func reactions(sectionId: String) async throws -> (counts: [ReactionType: Int], mine: ReactionType?) {
        async let countsRequest = api.send(ReaderAPI.reactionCounts(sectionId: sectionId))
        async let listRequest = api.send(ReaderAPI.reactions(sectionId: sectionId))
        let rawCounts = try await countsRequest
        let list = (try? await listRequest) ?? []
        var counts: [ReactionType: Int] = [:]
        for (key, value) in rawCounts {
            if let type = ReactionType(rawValue: key.uppercased()) { counts[type] = value }
        }
        let mine = list.first { $0.user.uuid == currentUserId }?.type
        return (counts, mine)
    }

    func addReaction(sectionId: String, _ type: ReactionType) async throws {
        _ = try await api.send(ReaderAPI.addReaction(sectionId: sectionId, type))
    }

    func removeReaction(sectionId: String) async throws {
        _ = try await api.send(ReaderAPI.removeReaction(sectionId: sectionId))
    }
}

/// Reviews of a single section (article / script page).
struct SectionReviewsSource: ReviewsSource {
    let sectionId: String
    let api: APIClient

    func reviews(page: Int) async throws -> Page<Review> {
        // Not paginated: everything comes in one list.
        let all = try await api.send(ReaderAPI.reviews(sectionId: sectionId))
            .sorted { $0.createdAt > $1.createdAt }
        return Page(content: all, number: 0, last: true, totalElements: all.count)
    }

    func save(editing reviewId: String?, _ request: ReviewRequest) async throws {
        if let reviewId {
            _ = try await api.send(ReaderAPI.updateReview(sectionId: sectionId, reviewId: reviewId, request))
        } else {
            _ = try await api.send(ReaderAPI.addReview(sectionId: sectionId, request))
        }
    }

    func delete(reviewId: String) async throws {
        _ = try await api.send(ReaderAPI.deleteReview(sectionId: sectionId, reviewId: reviewId))
    }
}

extension ReaderService {
    func sectionReviewsSource(sectionId: String) -> SectionReviewsSource {
        SectionReviewsSource(sectionId: sectionId, api: api)
    }
}

extension APIError {
    /// Offline or a server-side failure: worth trying again later.
    var isRetryable: Bool {
        switch self {
        case .noConnection: return true
        case .server(let status, _, _, _): return status >= 500
        default: return false
        }
    }
}

/// Progress that couldn't be sent yet, per section; keeps the highest percent and its read time.
private struct PendingProgressStore {
    struct Entry: Codable {
        let sectionId: String
        let percent: Double
        let readAt: Date
        let userId: String
    }

    private static let key = "reader_pending_progress_key"
    let defaults: UserDefaults

    private func load() -> [String: Entry] {
        guard let data = defaults.data(forKey: Self.key) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private func save(_ entries: [String: Entry]) {
        defaults.set(try? JSONEncoder().encode(entries), forKey: Self.key)
    }

    func store(sectionId: String, percent: Double, userId: String) {
        var entries = load()
        let previous = entries[sectionId].flatMap { $0.userId == userId ? $0.percent : nil } ?? 0
        entries[sectionId] = Entry(sectionId: sectionId, percent: max(previous, percent), readAt: Date(), userId: userId)
        save(entries)
    }

    func remove(sectionId: String, ifAtMost percent: Double) {
        var entries = load()
        guard let entry = entries[sectionId], entry.percent <= percent else { return }
        entries[sectionId] = nil
        save(entries)
    }

    /// Entries of other accounts are dropped: progress belongs to whoever recorded it.
    func entries(for userId: String) -> [Entry] {
        let all = load()
        let mine = all.filter { $0.value.userId == userId }
        if mine.count != all.count { save(mine) }
        return mine.values.sorted { $0.readAt < $1.readAt }
    }
}
