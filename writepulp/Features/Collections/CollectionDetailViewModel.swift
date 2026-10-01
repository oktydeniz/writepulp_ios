//
//  CollectionDetailViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class CollectionDetailViewModel {
    let collectionId: String
    private(set) var detail: CollectionDetail?
    private(set) var items = PagedList<CollectionItem>()
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let service: CollectionsService

    init(collectionId: String, service: CollectionsService) {
        self.collectionId = collectionId
        self.service = service
    }

    func load() async {
        isLoading = detail == nil
        defer { isLoading = false }
        do {
            let response = try await service.detail(id: collectionId, page: 0)
            detail = response
            items.apply(response.publications, replacing: true)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard items.hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await service.detail(id: collectionId, page: items.nextPage)
            items.apply(response.publications, replacing: false)
        } catch {
            // The next scroll retries.
        }
    }

    func toggleFollow() async {
        guard var detail else { return }
        do {
            try await service.toggleFollow(id: collectionId)
            detail.isFollowing.toggle()
            detail.followerCount = max(0, detail.followerCount + (detail.isFollowing ? 1 : -1))
            self.detail = detail
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func remove(_ item: CollectionItem) async {
        do {
            try await service.removePublication(item.id, from: collectionId)
            items.removeAll { $0.id == item.id }
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}
