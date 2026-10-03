//
//  GroupsViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class GroupsViewModel {
    enum Tab: Hashable {
        case mine, explore
    }

    enum Notice: Identifiable {
        case requestSent, requestWithdrawn
        var id: Self { self }
    }

    var tab: Tab = .mine
    var query = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }
    private(set) var owned: [CommunityGroup] = []
    private(set) var joined = PagedList<CommunityGroup>()
    private(set) var explore = PagedList<CommunityGroup>()
    private(set) var searchResults = PagedList<CommunityGroup>()
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isSearching = false
    private(set) var processingId: String?
    private(set) var errorMessage: String?
    var notice: Notice?
    var toastMessage: String?

    private let service: GroupsService
    private var searchTask: Task<Void, Never>?
    private static let minimumQueryLength = 2

    init(service: GroupsService) {
        self.service = service
    }

    var isSearchActive: Bool { trimmedQuery.count >= Self.minimumQueryLength }

    /// Joined groups the user doesn't own (owned ones have their own section).
    var joinedOnly: [CommunityGroup] {
        let ownedIds = Set(owned.map(\.id))
        return joined.items.filter { !ownedIds.contains($0.id) }
    }

    var exploreList: [CommunityGroup] { isSearchActive ? searchResults.items : explore.items }
    var hasLoaded: Bool { joined.hasLoaded || explore.hasLoaded }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - Loading

    func load() async {
        isLoading = !hasLoaded
        defer { isLoading = false }
        async let ownedRequest = service.owned()
        async let mineRequest = service.mine(page: 0)
        async let exploreRequest = service.explore(page: 0)
        do {
            let (ownedList, minePage, explorePage) = try await (ownedRequest, mineRequest, exploreRequest)
            owned = ownedList
            joined.apply(minePage, replacing: true)
            explore.apply(explorePage, replacing: true)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if !hasLoaded { errorMessage = error.localizedDescription } else { toastMessage = error.localizedDescription }
        }
    }

    func loadMoreIfNeeded(after group: CommunityGroup) async {
        switch tab {
        case .mine:
            guard group.id == joined.items.last?.id, joined.hasMore else { return }
            await loadMore(\.joined) { try await self.service.mine(page: $0) }
        case .explore where isSearchActive:
            guard group.id == searchResults.items.last?.id, searchResults.hasMore else { return }
            let query = trimmedQuery
            await loadMore(\.searchResults) { try await self.service.search(query, page: $0) }
        case .explore:
            guard group.id == explore.items.last?.id, explore.hasMore else { return }
            await loadMore(\.explore) { try await self.service.explore(page: $0) }
        }
    }

    private func loadMore(
        _ list: ReferenceWritableKeyPath<GroupsViewModel, PagedList<CommunityGroup>>,
        fetch: (Int) async throws -> Page<CommunityGroup>
    ) async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let page = try? await fetch(self[keyPath: list].nextPage) {
            self[keyPath: list].apply(page, replacing: false)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard isSearchActive else {
            searchResults = PagedList()
            isSearching = false
            return
        }
        let query = trimmedQuery
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                let page = try await service.search(query, page: 0)
                guard !Task.isCancelled else { return }
                searchResults.apply(page, replacing: true)
            } catch APIError.cancelled {
            } catch {
                toastMessage = error.localizedDescription
            }
            if !Task.isCancelled { isSearching = false }
        }
    }

    // MARK: - Membership

    func join(_ group: CommunityGroup) async {
        guard processingId == nil else { return }
        processingId = group.id
        defer { processingId = nil }
        do {
            try await service.join(id: group.id)
            if group.isPrivate {
                setStatus(.pending, of: group.id)
                notice = .requestSent
            } else {
                var member = group
                member.userStatus = .joined
                member.memberCount += 1
                explore.removeAll { $0.id == group.id }
                searchResults.update(where: { $0.id == group.id }) { $0 = member }
                await reloadJoined()
            }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func withdrawRequest(_ group: CommunityGroup) async {
        guard processingId == nil else { return }
        processingId = group.id
        defer { processingId = nil }
        do {
            try await service.withdrawRequest(id: group.id)
            setStatus(.none, of: group.id)
            notice = .requestWithdrawn
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    private func reloadJoined() async {
        if let page = try? await service.mine(page: 0) { joined.apply(page, replacing: true) }
    }

    private func setStatus(_ status: GroupUserStatus, of id: String) {
        explore.update(where: { $0.id == id }) { $0.userStatus = status }
        searchResults.update(where: { $0.id == id }) { $0.userStatus = status }
    }
}
