//
//  CollectionsViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// The signed-in user's collections and the ones they follow.
@MainActor
@Observable
final class CollectionsViewModel {
    enum Tab: Hashable {
        case mine, followed
    }

    var tab: Tab = .mine
    private(set) var mine: [UserCollection] = []
    private(set) var followed: [UserCollection] = []
    private(set) var hasLoadedFollowed = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let service: CollectionsService

    init(service: CollectionsService) {
        self.service = service
    }

    var current: [UserCollection] { tab == .mine ? mine : followed }

    func load() async {
        isLoading = current.isEmpty
        defer { isLoading = false }
        do {
            switch tab {
            case .mine:
                mine = try await service.collections(of: nil)
            case .followed:
                followed = try await service.followedCollections()
                hasLoadedFollowed = true
            }
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func tabChanged() async {
        if tab == .followed && !hasLoadedFollowed { await load() }
    }

    /// Returns the error message to show in the editor, nil on success.
    func save(_ form: CollectionForm, editing collection: UserCollection?) async -> String? {
        do {
            if let collection {
                try await service.update(id: collection.uuid, form)
            } else {
                try await service.create(form)
            }
            mine = try await service.collections(of: nil)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func delete(_ collection: UserCollection) async {
        do {
            try await service.delete(id: collection.uuid)
            mine.removeAll { $0.uuid == collection.uuid }
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    /// Removed right away; restored if the request fails.
    func unfollow(_ collection: UserCollection) async {
        let previous = followed
        followed.removeAll { $0.uuid == collection.uuid }
        do {
            try await service.toggleFollow(id: collection.uuid)
        } catch {
            followed = previous
            toastMessage = error.localizedDescription
        }
    }
}
