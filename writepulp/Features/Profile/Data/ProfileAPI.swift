//
//  ProfileAPI.swift
//  writepulp
//

import Foundation

enum ProfileAPI {
    static let pageSize = 20

    static func profile(userId: String?) -> Endpoint<UserProfile> {
        Endpoint(path: userId.map { "profile/\($0)" } ?? "profile/me")
    }

    static func editableProfile() -> Endpoint<EditableProfile> {
        Endpoint(path: "profile/edit")
    }

    static func update(_ request: ProfileUpdateRequest) -> Endpoint<ProfileUpdateResult> {
        Endpoint(path: "profile", method: .put, body: request)
    }

    static func publications(userId: String?, page: Int) -> Endpoint<Page<PublicationSummary>> {
        Endpoint(
            path: userId.map { "publications/author/\($0)" } ?? "publications/me",
            query: pageQuery(page)
        )
    }

    static func toggleFollow(userId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "follows/toggle/\(userId)", method: .post)
    }

    static func respondToFollowRequest(userId: String, approve: Bool) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "follows/process-request/\(userId)",
            method: .post,
            query: [URLQueryItem(name: "approve", value: "\(approve)")]
        )
    }

    /// The signed-in user's own lists have dedicated endpoints.
    static func follows(userId: String?, kind: FollowListKind, page: Int) -> Endpoint<Page<FollowUser>> {
        guard let userId else {
            return Endpoint(path: kind == .followers ? "follows/followers" : "follows/following", query: pageQuery(page))
        }
        let type = URLQueryItem(name: "type", value: kind == .followers ? "followers" : "following")
        return Endpoint(path: "follows/\(userId)/follows", query: [type] + pageQuery(page))
    }

    private static func pageQuery(_ page: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(pageSize)")]
    }
}
