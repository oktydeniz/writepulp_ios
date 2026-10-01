//
//  CollectionsService.swift
//  writepulp
//

import Foundation

@MainActor
final class CollectionsService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    /// nil means the signed-in user's own collections.
    func collections(of userId: String?) async throws -> [UserCollection] {
        try await api.send(userId.map(CollectionsAPI.ofUser) ?? CollectionsAPI.mine())
    }

    func followedCollections() async throws -> [UserCollection] {
        try await api.send(CollectionsAPI.followed())
    }

    func detail(id: String, page: Int) async throws -> CollectionDetail {
        try await api.send(CollectionsAPI.detail(id: id, page: page))
    }

    func create(_ form: CollectionForm) async throws {
        _ = try await api.send(CollectionsAPI.create(form))
    }

    func update(id: String, _ form: CollectionForm) async throws {
        _ = try await api.send(CollectionsAPI.update(id: id, form))
    }

    func delete(id: String) async throws {
        _ = try await api.send(CollectionsAPI.delete(id: id))
    }

    func toggleFollow(id: String) async throws {
        _ = try await api.send(CollectionsAPI.toggleFollow(id: id))
    }

    func addPublication(_ publicationId: String, to collectionId: String) async throws {
        _ = try await api.send(CollectionsAPI.addPublication(collectionId: collectionId, publicationId: publicationId))
    }

    func removePublication(_ publicationId: String, from collectionId: String) async throws {
        _ = try await api.send(CollectionsAPI.removePublication(collectionId: collectionId, publicationId: publicationId))
    }
}
