//
//  PocketViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// The user's library grouped by status. Status changes and resets apply right away and roll back on failure.
@MainActor
@Observable
final class PocketViewModel {
    var tab: LibraryStatus = .reading
    var query = ""
    private(set) var lastRead: LibraryItem?
    private(set) var groups: [LibraryStatus: [LibraryItem]] = [:]
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let service: PocketService

    init(service: PocketService) {
        self.service = service
    }

    func count(of status: LibraryStatus) -> Int {
        groups[status]?.count ?? 0
    }

    /// The active tab, filtered by title or author.
    var items: [LibraryItem] {
        let all = groups[tab] ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.publication.title.localizedCaseInsensitiveContains(trimmed)
                || $0.publication.author.fullName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func load() async {
        isLoading = !hasLoaded
        defer { isLoading = false }
        do {
            let library = try await service.library()
            lastRead = library.lastReadItem
            groups = library.groups
            hasLoaded = true
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(_ item: LibraryItem, to status: LibraryStatus) async {
        let previous = groups
        var moved = item
        moved.status = status
        for key in groups.keys {
            groups[key]?.removeAll { $0.id == item.id }
        }
        groups[status, default: []].insert(moved, at: 0)
        do {
            try await service.changeStatus(publicationId: item.id, to: status)
        } catch {
            groups = previous
            toastMessage = error.localizedDescription
        }
    }

    func resetProgress(_ item: LibraryItem) async {
        let previous = groups
        for key in groups.keys {
            guard let index = groups[key]?.firstIndex(where: { $0.id == item.id }) else { continue }
            groups[key]?[index].progressPercent = 0
        }
        do {
            try await service.resetProgress(publicationId: item.id)
        } catch {
            groups = previous
            toastMessage = error.localizedDescription
        }
    }
}
