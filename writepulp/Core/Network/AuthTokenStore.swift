//
//  AuthTokenStore.swift
//  writepulp
//

import Foundation

/// What the API client needs from the session; implemented by SessionStore.
@MainActor
protocol AuthTokenStore: AnyObject {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func updateTokens(accessToken: String, refreshToken: String)
    /// Refresh failed: clear the local session and let the UI send the user to login.
    func expireSession()
}
