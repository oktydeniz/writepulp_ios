//
//  APIClient.swift
//  writepulp
//

import Foundation

/// Single entry point for backend calls: builds requests, adds auth / language headers,
/// unwraps the response envelope and refreshes the access token once on 401.
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: any AuthTokenStore
    private let languageCode: @Sendable () -> String
    private let logger: NetworkLogger?

    /// Shared by concurrent requests that hit 401 together, so the token is refreshed once.
    private var refreshTask: Task<RefreshResult, Never>?

    init(
        baseURL: URL,
        tokenStore: any AuthTokenStore,
        languageCode: @escaping @Sendable () -> String,
        logger: NetworkLogger? = nil,
        session: URLSession = APIClient.defaultSession
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.languageCode = languageCode
        self.logger = logger
        self.session = session
    }

    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()

    func send<T: Decodable>(_ endpoint: Endpoint<T>) async throws -> T {
        let token = endpoint.requiresAuth ? await tokenStore.accessToken : nil
        let (data, response) = try await perform(endpoint, token: token)

        if response.statusCode == 401, endpoint.requiresAuth, token != nil {
            switch await refreshAccessToken(after: token) {
            case .refreshed: break
            case .expired: throw APIError.sessionExpired
            case .failed(let error): throw error
            }
            let retryToken = await tokenStore.accessToken
            let (retryData, retryResponse) = try await perform(endpoint, token: retryToken)
            return try decode(retryData, response: retryResponse)
        }
        return try decode(data, response: response)
    }

    // MARK: - Request

    private func perform<T>(_ endpoint: Endpoint<T>, token: String?) async throws -> (Data, HTTPURLResponse) {
        let request = try makeRequest(endpoint, token: token)
        logger?.log(request: request)
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            logger?.log(response: http, data: data, for: request, duration: Date().timeIntervalSince(start))
            return (data, http)
        } catch let error as URLError {
            logger?.log(error: error, for: request)
            switch error.code {
            case .cancelled: throw APIError.cancelled
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut, .dataNotAllowed:
                throw APIError.noConnection
            default: throw APIError.invalidResponse
            }
        } catch is CancellationError {
            throw APIError.cancelled
        }
    }

    private func makeRequest<T>(_ endpoint: Endpoint<T>, token: String?) throws -> URLRequest {
        let path = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty { components?.queryItems = endpoint.query }
        guard let url = components?.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(languageCode(), forHTTPHeaderField: "Accept-Language")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encoder.encode(body)
        }
        return request
    }

    // MARK: - Response

    private func decode<T: Decodable>(_ data: Data, response: HTTPURLResponse) throws -> T {
        // Absent for non-envelope bodies, e.g. Spring Security's own 403.
        let envelope = try? JSONCoding.decoder.decode(APIEnvelope.self, from: data)

        guard (200..<300).contains(response.statusCode), envelope?.success != false else {
            throw APIError.server(
                status: response.statusCode,
                businessCode: envelope?.businessCode,
                message: envelope?.message,
                body: data
            )
        }
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }

        let decoded: APIResponse<T>
        do {
            decoded = try JSONCoding.decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
        guard let value = decoded.data else { throw APIError.invalidResponse }
        return value
    }

    // MARK: - Token refresh

    private enum RefreshResult {
        case refreshed
        /// The backend rejected the refresh token; the session has been cleared.
        case expired
        /// Offline or server trouble: the session is kept and the original call fails with this.
        case failed(APIError)
    }
    private struct RefreshRequest: Encodable { let refreshToken: String }
    private struct TokenPair: Decodable { let accessToken: String; let refreshToken: String }

    private func refreshAccessToken(after failedToken: String?) async -> RefreshResult {
        // Another request already refreshed while this one was in flight.
        if let current = await tokenStore.accessToken, current != failedToken { return .refreshed }
        if let refreshTask { return await refreshTask.value }

        let task = Task { await performRefresh() }
        refreshTask = task
        let refreshed = await task.value
        refreshTask = nil
        return refreshed
    }

    private func performRefresh() async -> RefreshResult {
        guard let refreshToken = await tokenStore.refreshToken, !refreshToken.isEmpty else {
            await tokenStore.expireSession()
            return .expired
        }
        let endpoint = Endpoint<TokenPair>(
            path: "auth/refresh",
            method: .post,
            body: RefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        )
        do {
            let (data, response) = try await perform(endpoint, token: nil)
            let tokens: TokenPair = try decode(data, response: response)
            await tokenStore.updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            return .refreshed
        } catch let error as APIError {
            if case .server(let status, _, _, _) = error, (400..<500).contains(status) {
                await tokenStore.expireSession()
                return .expired
            }
            return .failed(error)
        } catch {
            return .failed(.invalidResponse)
        }
    }
}
