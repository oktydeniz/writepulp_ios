//
//  HomeViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var feed: HomeFeed?
    private(set) var communities: [CommunityPreview] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isInspirationDismissed = false
    let inspirationIndex: Int

    private let service: HomeService
    private let preferences: AppPreferences

    init(service: HomeService, preferences: AppPreferences) {
        self.service = service
        self.preferences = preferences
        inspirationIndex = preferences.inspirationBoxTodayIndex(total: InspirationItem.total)
    }

    var showsInspiration: Bool { preferences.isInspirationBoxEnabled && !isInspirationDismissed }

    func loadIfNeeded() async {
        guard feed == nil, !isLoading else { return }
        await load()
    }

    /// First load shows the skeleton; pull-to-refresh keeps the current feed on screen.
    func load() async {
        isLoading = feed == nil
        defer { isLoading = false }
        do {
            let feed = try await service.feed()
            self.feed = feed
            errorMessage = nil
            communities = await service.communityPreviews(ids: Array(feed.communityGroupIds.prefix(4)))
        } catch APIError.cancelled {
        } catch {
            if feed == nil { errorMessage = error.localizedDescription }
        }
    }

    func dismissInspiration() {
        isInspirationDismissed = true
    }
}
