//
//  NetworkLogger.swift
//  writepulp
//

import Foundation
import OSLog

/// Request/response logging for dev builds, with credentials masked.
struct NetworkLogger {
    private static let sensitiveKeys = [
        "password", "passwordVerify", "newPassword", "newPasswordVerify", "token", "accessToken",
        "refreshToken", "creditCardNumber", "ssn", "verifyCode", "code", "fcmToken", "Authorization",
    ]

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "writepulp", category: "network")

    func log(request: URLRequest) {
        let headers = (request.allHTTPHeaderFields ?? [:])
            .map { "\($0.key): \(Self.sensitiveKeys.contains($0.key) ? "****" : $0.value)" }
            .sorted()
            .joined(separator: "\n")
        let body = request.httpBody.map { Self.mask(String(decoding: $0, as: UTF8.self)) } ?? ""
        logger.debug("--> \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")\n\(headers)\n\(body)")
    }

    func log(response: HTTPURLResponse, data: Data, for request: URLRequest, duration: TimeInterval) {
        let body = Self.mask(String(decoding: data.prefix(4_000), as: UTF8.self))
        logger.debug("<-- \(response.statusCode) \(request.url?.absoluteString ?? "") (\(Int(duration * 1000))ms)\n\(body)")
    }

    func log(error: Error, for request: URLRequest) {
        logger.error("<-- FAILED \(request.url?.absoluteString ?? ""): \(error.localizedDescription)")
    }

    private static func mask(_ text: String) -> String {
        sensitiveKeys.reduce(text) { result, key in
            result.replacingOccurrences(
                of: "(\"\(key)\"\\s*:\\s*\")[^\"]*",
                with: "$1****",
                options: .regularExpression
            )
        }
    }
}
