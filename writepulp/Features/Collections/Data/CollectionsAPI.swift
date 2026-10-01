//
//  CollectionsAPI.swift
//  writepulp
//

import Foundation

enum CollectionsAPI {
    static func mine() -> Endpoint<[UserCollection]> {
        Endpoint(path: "collections")
    }

    static func ofUser(_ userId: String) -> Endpoint<[UserCollection]> {
        Endpoint(path: "collections/user/\(userId)")
    }

    static func followed() -> Endpoint<[UserCollection]> {
        Endpoint(path: "collections/followed")
    }

    static func detail(id: String, page: Int) -> Endpoint<CollectionDetail> {
        Endpoint(path: "collections/\(id)/detail", query: [URLQueryItem(name: "page", value: "\(page)")])
    }

    static func create(_ form: CollectionForm) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections", method: .post, body: form)
    }

    static func update(id: String, _ form: CollectionForm) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(id)", method: .put, body: form)
    }

    static func delete(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(id)", method: .delete)
    }

    static func toggleFollow(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(id)/follow", method: .post)
    }

    static func addPublication(collectionId: String, publicationId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(collectionId)/publications/\(publicationId)", method: .post)
    }

    static func removePublication(collectionId: String, publicationId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "collections/\(collectionId)/publications/\(publicationId)", method: .delete)
    }
}
