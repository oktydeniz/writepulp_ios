//
//  Endpoint.swift
//  writepulp
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describes one API call and the type its `data` field decodes to.
/// Feature modules declare these, e.g. `Endpoint<LoginData>(path: "auth/login", method: .post, body: req)`.
struct Endpoint<Response: Decodable> {
    var path: String
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var body: (any Encodable)?
    /// Sent instead of `body` for file uploads.
    var multipart: MultipartForm?
    /// Sends the access token when there is one; guests call these without it.
    var requiresAuth = true
}

/// For calls whose `data` is empty or irrelevant.
struct EmptyResponse: Decodable {}
