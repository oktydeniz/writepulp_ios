//
//  FollowListViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Followers and following of one user, each paged separately.
@MainActor
@Observable
final class FollowListViewModel {
    /// nil is the signed-in user.
    let userId: String?
    var kind: FollowListKind
    var query = ""
    private(set) var lists: [FollowListKind: PagedList<FollowUser>] = [:]
    /// Tracked per list so switching tabs mid-load still loads the other one.
    private var loadingKinds: Set<FollowListKind> = []
    private var errors: [FollowListKind: String] = [:]
    var toastMessage: String?

    private let service: ProfileService

    init(userId: String?, kind: FollowListKind, service: ProfileService) {
        self.userId = userId
        self.kind = kind
        self.service = service
    }

    private var current: PagedList<FollowUser> { lists[kind] ?? PagedList() }

    var hasLoaded: Bool { current.hasLoaded }
    var isLoading: Bool { loadingKinds.contains(kind) }
    var errorMessage: String? { errors[kind] }

    /// Search filters what is already loaded.
    var users: [FollowUser] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return current.items }
        return current.items.filter {
            $0.fullName.localizedCaseInsensitiveContains(trimmed) || $0.handle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Each list is fetched once; revisiting the tab or the screen reuses it until refreshed.
    func loadIfNeeded() async {
        if !current.hasLoaded { await load(replacing: true) }
    }

    func refresh() async {
        await load(replacing: true)
    }

    func loadMore() async {
        guard query.isEmpty, current.hasMore, current.hasLoaded else { return }
        await load(replacing: false)
    }

    private func load(replacing: Bool) async {
        let kind = kind
        guard !loadingKinds.contains(kind) else { return }
        loadingKinds.insert(kind)
        defer { loadingKinds.remove(kind) }
        do {
            let page = try await service.follows(
                userId: userId,
                kind: kind,
                page: replacing ? 0 : lists[kind]?.nextPage ?? 0
            )
            lists[kind, default: PagedList()].apply(page, replacing: replacing)
            errors[kind] = nil
        } catch APIError.cancelled {
        } catch {
            errors[kind] = error.localizedDescription
        }
    }

    func toggleFollow(_ user: FollowUser) async {
        do {
            try await service.toggleFollow(userId: user.uuid)
            updateEverywhere(user.uuid) { $0.applyFollowToggle() }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func approveRequest(from user: FollowUser) async {
        do {
            try await service.respondToFollowRequest(userId: user.uuid, approve: true)
            updateEverywhere(user.uuid) { $0.applyRequestResponse(approved: true) }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    /// The same person can be in both lists.
    private func updateEverywhere(_ userId: String, _ change: (inout FollowUser) -> Void) {
        for key in lists.keys {
            lists[key]?.update(where: { $0.uuid == userId }, change)
        }
    }
}
