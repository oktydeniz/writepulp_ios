//
//  AuthModels.swift
//  writepulp
//

import Foundation

struct LoginData: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let user: UserDto
}

struct UserDto: Codable, Equatable {
    let id: String
    let email: String
    let handle: String
    let fullName: String
    let avatarImg: String?
    let role: String
}
