//
//  AuthModels.swift
//  writepulp
//

import Foundation

struct LoginData: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let user: UserDto
    /// Set by auth/social when that sign-in created the account.
    var newUser: Bool? = nil
}

struct UserDto: Codable, Equatable {
    let id: String
    let email: String
    let handle: String
    let fullName: String
    let avatarImg: String?
    let role: String
    /// false for Apple/Google accounts that never set a password; nil from older responses.
    var hasPassword: Bool? = nil
}
