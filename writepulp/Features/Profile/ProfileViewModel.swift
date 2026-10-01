//
//  ProfileViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// One profile (own or someone else's): header, works and collections.
@MainActor
@Observable
final class ProfileViewModel {
    enum Tab: Hashable, CaseIterable {
        case about, works, lists
    }

    /// nil is the signed-in user.
    let userId: String?
    var tab: Tab = .about
    private(set) var profile: UserProfile?
    private(set) var works = PagedList<PublicationSummary>()
    private(set) var collections: [UserCollection] = []
    private(set) var isLoading = false
    private(set) var isLoadingWorks = false
    private(set) var isFollowBusy = false
    private(set) var error: Error?
    var toastMessage: String?

    private let profileService: ProfileService
    private let collectionsService: CollectionsService

    init(userId: String?, profileService: ProfileService, collectionsService: CollectionsService) {
        self.userId = userId
        self.profileService = profileService
        self.collectionsService = collectionsService
    }

    var isMe: Bool { profile?.isMe ?? (userId == nil) }

    /// Profile, first works page and collections together. Keeps the current content while refreshing.
    func load() async {
        isLoading = profile == nil
        defer { isLoading = false }
        async let profile = profileService.profile(userId: userId)
        async let works = profileService.publications(userId: userId, page: 0)
        async let collections = collectionsService.collections(of: userId)
        do {
            self.profile = try await profile
            error = nil
        } catch APIError.cancelled {
            return
        } catch {
            self.error = error
            return
        }
        // A private profile the viewer can't see answers these with errors; the header still shows.
        if let page = try? await works { self.works.apply(page, replacing: true) }
        if let list = try? await collections { self.collections = list }
    }

    func loadMoreWorks() async {
        guard works.hasMore, !isLoadingWorks, works.hasLoaded else { return }
        isLoadingWorks = true
        defer { isLoadingWorks = false }
        do {
            let page = try await profileService.publications(userId: userId, page: works.nextPage)
            works.apply(page, replacing: false)
        } catch {
            // The next scroll retries.
        }
    }

    func toggleFollow() async {
        guard var profile, !isFollowBusy else { return }
        isFollowBusy = true
        defer { isFollowBusy = false }
        do {
            try await profileService.toggleFollow(userId: profile.uuid)
            let couldSeeContent = profile.isContentVisible
            profile.applyFollowToggle()
            self.profile = profile
            if !couldSeeContent && profile.isContentVisible { await load() }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func saveCollection(_ form: CollectionForm) async -> String? {
        do {
            try await collectionsService.create(form)
            collections = try await collectionsService.collections(of: nil)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
