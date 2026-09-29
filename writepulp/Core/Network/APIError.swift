//
//  APIError.swift
//  writepulp
//

import Foundation

enum APIError: Error {
    case noConnection
    /// Non-2xx or `success == false`. `body` is the raw response, for error payloads (see `payload`).
    case server(status: Int, businessCode: Int?, message: String?, body: Data?)
    /// Refresh failed; the local session has already been cleared.
    case sessionExpired
    case decoding(Error)
    case invalidResponse
    case cancelled

    var businessCode: Int? {
        if case .server(_, let code, _, _) = self { return code }
        return nil
    }

    /// Spring Security's own 401/403 (no business code): the call needs a signed-in user,
    /// e.g. a guest hitting a protected endpoint. Screens can offer login instead of an error.
    var requiresSignIn: Bool {
        if case .server(let status, nil, _, _) = self { return status == 401 || status == 403 }
        return false
    }

    /// Decodes the `data` field of an error response, e.g. `{ "email": ... }` for USER_NOT_VERIFIED.
    func payload<T: Decodable>(_ type: T.Type) -> T? {
        guard case .server(_, _, _, let body?) = self else { return nil }
        return (try? JSONCoding.decoder.decode(APIResponse<T>.self, from: body))?.data
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return String(localized: "error_no_internet")
        case .server(let status, let code, let message, _):
            switch code {
            case BusinessCode.insufficientCredit: return String(localized: "error_insufficient_credit")
            case BusinessCode.walletBalance: return String(localized: "error_wallet_balance")
            case BusinessCode.categoryNotFound: return String(localized: "error_category_not_found")
            default:
                if let message, !message.isEmpty { return message }
                switch status {
                case 404: return String(localized: "error_not_found")
                case 500...: return String(localized: "error_server")
                default: return String(localized: "error_unknown")
                }
            }
        case .sessionExpired:
            return String(localized: "session_expired_message")
        case .decoding, .invalidResponse, .cancelled:
            return String(localized: "error_unknown")
        }
    }
}

enum JSONCoding {
    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()
}
