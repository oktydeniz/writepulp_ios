//
//  PublicationService.swift
//  writepulp
//

import Foundation

enum PublicationAPI {
    static let pageSize = 20

    static func detail(id: String) -> Endpoint<PublicationDetail> {
        Endpoint(path: "publications/\(id)")
    }

    static func incrementView(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(id)/view", method: .post)
    }

    static func sections(publicationId: String, page: Int) -> Endpoint<Page<PublicationSection>> {
        Endpoint(path: "sections/publication/\(publicationId)", query: pageQuery(page))
    }

    static func reviews(publicationId: String, page: Int) -> Endpoint<Page<Review>> {
        Endpoint(
            path: "publications/\(publicationId)/reviews",
            query: pageQuery(page) + [
                URLQueryItem(name: "sortBy", value: "createdAt"),
                URLQueryItem(name: "direction", value: "DESC"),
            ]
        )
    }

    static func addReview(publicationId: String, _ request: ReviewRequest) -> Endpoint<Review> {
        Endpoint(path: "publications/\(publicationId)/reviews", method: .post, body: request)
    }

    static func updateReview(publicationId: String, reviewId: String, _ request: ReviewRequest) -> Endpoint<Review> {
        Endpoint(path: "publications/\(publicationId)/reviews/\(reviewId)", method: .put, body: request)
    }

    static func deleteReview(publicationId: String, reviewId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(publicationId)/reviews/\(reviewId)", method: .delete)
    }

    private static func pageQuery(_ page: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(pageSize)")]
    }
}

@MainActor
final class PublicationService {
    private let api: APIClient
    private let session: SessionStore

    nonisolated init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    var isSignedIn: Bool { session.isLoggedIn }
    var currentUserId: String? { session.userId }

    func detail(id: String) async throws -> PublicationDetail {
        try await api.send(PublicationAPI.detail(id: id))
    }

    func incrementView(id: String) async {
        _ = try? await api.send(PublicationAPI.incrementView(id: id))
    }

    func sections(publicationId: String, page: Int) async throws -> Page<PublicationSection> {
        try await api.send(PublicationAPI.sections(publicationId: publicationId, page: page))
    }

    /// Free claims and coin purchases both go through the wallet.
    func addToLibrary(_ publication: PublicationDetail) async throws {
        _ = try await api.send(WalletAPI.purchase(contentId: publication.uuid, costInCoin: publication.priceCoin))
    }

    func reviews(publicationId: String, page: Int) async throws -> Page<Review> {
        try await api.send(PublicationAPI.reviews(publicationId: publicationId, page: page))
    }

    func saveReview(publicationId: String, editing reviewId: String?, _ request: ReviewRequest) async throws -> Review {
        if let reviewId {
            return try await api.send(PublicationAPI.updateReview(publicationId: publicationId, reviewId: reviewId, request))
        }
        return try await api.send(PublicationAPI.addReview(publicationId: publicationId, request))
    }

    func deleteReview(publicationId: String, reviewId: String) async throws {
        _ = try await api.send(PublicationAPI.deleteReview(publicationId: publicationId, reviewId: reviewId))
    }
}
