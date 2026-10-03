//
//  DownloadManager.swift
//  writepulp
//

import Observation
import UIKit

/// App-wide owner of downloads: the list, running jobs and their progress. Jobs keep running
/// when the screen that started them goes away. Created off the main actor at launch; all of its
/// behavior is main-actor isolated (see the extension).
@Observable
final class DownloadManager {
    private(set) var downloads: [DownloadedPublication] = []
    private(set) var progress: [String: DownloadProgress] = [:]
    private(set) var hasLoaded = false

    @ObservationIgnored private let store: DownloadStore
    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let session: SessionStore
    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let network: NetworkMonitor
    @ObservationIgnored private var jobs: [String: Task<DownloadOutcome, Never>] = [:]
    @ObservationIgnored private var loadedOwnerId: String?
    @ObservationIgnored private var didCheckStale = false

    init(
        store: DownloadStore,
        api: APIClient,
        session: SessionStore,
        preferences: AppPreferences,
        network: NetworkMonitor
    ) {
        self.store = store
        self.api = api
        self.session = session
        self.preferences = preferences
        self.network = network
    }
}

@MainActor
extension DownloadManager {
    func download(for id: String) -> DownloadedPublication? {
        downloads.first { $0.id == id }
    }

    func coverURL(of download: DownloadedPublication) -> URL? {
        download.coverFile.map { store.mediaURL(publicationId: download.id, file: $0) }
    }

    func canDownload(_ detail: PublicationDetail) -> Bool {
        session.isLoggedIn && (detail.hasAccess || detail.hasEditRole)
    }

    /// Loads the current account's downloads and removes ones left by another account.
    func prepare() async {
        guard let userId = session.userId, session.isLoggedIn else {
            downloads = []
            loadedOwnerId = nil
            hasLoaded = false
            return
        }
        guard loadedOwnerId != userId else { return }
        loadedOwnerId = userId
        let all = await store.all()
        for foreign in all where foreign.ownerId != userId {
            await store.delete(foreign.id)
        }
        setDownloads(all.filter { $0.ownerId == userId })
        hasLoaded = true
    }

    // MARK: - Jobs

    /// Downloads, or re-downloads if a copy already exists.
    @discardableResult
    func download(_ detail: PublicationDetail) async -> DownloadOutcome {
        await run(detail.uuid) { detail }
    }

    /// Re-downloads with fresh details. A failed update keeps the existing copy.
    @discardableResult
    func refresh(_ id: String) async -> DownloadOutcome {
        await run(id) { [api] in try? await api.send(PublicationAPI.detail(id: id)) }
    }

    func delete(_ id: String) async {
        jobs[id]?.cancel()
        await store.delete(id)
        setDownloads(downloads.filter { $0.id != id })
    }

    var autoUpdateDays: Int { preferences.downloadAutoUpdateDays }

    func setAutoUpdateDays(_ days: Int) {
        preferences.setDownloadAutoUpdateDays(days)
        DownloadRefreshTask.schedule(autoUpdateDays: days)
    }

    /// Foreground fallback for the background task: once per launch, on Wi-Fi.
    func refreshStaleIfNeeded() async {
        guard !didCheckStale, hasLoaded, network.isOnUnmeteredNetwork else { return }
        didCheckStale = true
        await refreshStale()
    }

    /// Re-downloads copies older than the auto-update setting while on Wi-Fi. Cancelling stops the
    /// current copy too; it keeps its old version.
    func refreshStale() async {
        await prepare()
        let days = autoUpdateDays
        guard days > 0 else { return }
        let threshold = Date().addingTimeInterval(-Double(days) * 86_400)
        for stale in downloads where stale.downloadedAt <= threshold {
            guard !Task.isCancelled, network.isOnUnmeteredNetwork else { return }
            let id = stale.id
            _ = await withTaskCancellationHandler {
                await refresh(id)
            } onCancel: {
                Task { @MainActor in self.jobs[id]?.cancel() }
            }
        }
    }

    private func run(_ id: String, detail: @escaping () async -> PublicationDetail?) async -> DownloadOutcome {
        if let running = jobs[id] { return await running.value }
        guard let ownerId = session.userId else { return .failed }
        guard network.isOnline else { return .offline }

        progress[id] = DownloadProgress(completed: 0, total: 0)
        let downloader = Downloader(api: api, store: store)
        let includeMedia = preferences.isDownloadMediaEnabled
        let job = Task {
            // A little extra time to finish if the app is sent to the background mid-download.
            let background = UIApplication.shared.beginBackgroundTask(withName: "download-\(id)")
            defer { UIApplication.shared.endBackgroundTask(background) }
            guard let detail = await detail() else { return DownloadOutcome.failed }
            return await downloader.run(detail, ownerId: ownerId, includeMedia: includeMedia) { [weak self] value in
                if self?.jobs[id] != nil { self?.progress[id] = value }
            }
        }
        jobs[id] = job
        let outcome = await job.value
        jobs[id] = nil
        progress[id] = nil
        if outcome == .completed || outcome == .partial, let saved = await store.publication(id) {
            setDownloads(downloads.filter { $0.id != id } + [saved])
        }
        return outcome
    }

    private func setDownloads(_ list: [DownloadedPublication]) {
        downloads = list.sorted { $0.downloadedAt > $1.downloadedAt }
    }
}
