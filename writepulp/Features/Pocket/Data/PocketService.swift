//
//  PocketService.swift
//  writepulp
//

import Foundation

enum PocketAPI {
    static func library() -> Endpoint<Library> {
        Endpoint(path: "library/me")
    }

    static func changeStatus(publicationId: String, to status: LibraryStatus) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "library/publications/\(publicationId)/status",
            method: .patch,
            query: [URLQueryItem(name: "status", value: status.rawValue)]
        )
    }

    static func resetProgress(publicationId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "library/publications/\(publicationId)/reset", method: .post)
    }
}

@MainActor
final class PocketService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    func library() async throws -> Library {
        try await api.send(PocketAPI.library())
    }

    func changeStatus(publicationId: String, to status: LibraryStatus) async throws {
        _ = try await api.send(PocketAPI.changeStatus(publicationId: publicationId, to: status))
    }

    func resetProgress(publicationId: String) async throws {
        _ = try await api.send(PocketAPI.resetProgress(publicationId: publicationId))
    }
}
