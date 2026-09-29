//
//  APIResponse.swift
//  writepulp
//

import Foundation

/// Backend envelope: every response (success or error) has this shape.
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let status: Int
    let businessCode: Int?
    let message: String?
    let data: T?
}

/// The envelope without `data`, so status/message can be read whatever `data` holds.
struct APIEnvelope: Decodable {
    let success: Bool
    let businessCode: Int?
    let message: String?
}

/// Backend `BusinessErrorCode` values the app reacts to.
enum BusinessCode {
    static let insufficientCredit = 123
    static let userNotVerified = 1405
    static let categoryNotFound = 14004
    static let walletBalance = 16100
}
