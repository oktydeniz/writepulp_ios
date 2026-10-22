//
//  ModerationAPI.swift
//  writepulp
//

import Foundation

enum ModerationAPI {
    static func report(_ request: CreateReportRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "reports", method: .post, body: request)
    }

    static func block(userId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "blocks/\(userId)", method: .post)
    }

    static func unblock(userId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "blocks/\(userId)", method: .delete)
    }

    static func blockedUsers(page: Int, size: Int = 50) -> Endpoint<Page<BlockedUser>> {
        Endpoint(
            path: "blocks",
            query: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(size)")]
        )
    }

    static func termsStatus() -> Endpoint<TermsStatus> {
        Endpoint(path: "profile/terms")
    }

    static func acceptTerms(version: String) -> Endpoint<TermsStatus> {
        Endpoint(path: "profile/terms", method: .post, body: AcceptTermsRequest(version: version))
    }
}
