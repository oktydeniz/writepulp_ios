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
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let service: ProfileService

    init(userId: String?, kind: FollowListKind, service: ProfileService) {
        self.userId = userId
        self.kind = kind
        self.service = service
    }

    private var current: PagedList<FollowUser> { lists[kind] ?? PagedList() }

    var hasLoaded: Bool { current.hasLoaded }

    /// Search filters what is already loaded.
    var users: [FollowUser] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return current.items }
        return current.items.filter {
            $0.fullName.localizedCaseInsensitiveContains(trimmed) || $0.handle.localizedCaseInsensitiveContains(trimmed)
        }
    }

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
        guard !isLoading else { return }
        let kind = kind
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await service.follows(
                userId: userId,
                kind: kind,
                page: replacing ? 0 : current.nextPage
            )
            lists[kind, default: PagedList()].apply(page, replacing: replacing)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
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
