//
//  FormValidator.swift
//  writepulp
//

import Foundation

/// Each check returns nil when valid, otherwise the localized message to show.
enum FormValidator {
    static let minPasswordLength = 8
    static let otpLength = 6

    static func email(_ value: String) -> String? {
        let email = value.trimmingCharacters(in: .whitespaces)
        if email.isEmpty { return String(localized: "err_email_empty") }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        if email.range(of: pattern, options: .regularExpression) == nil {
            return String(localized: "err_email_invalid")
        }
        return nil
    }

    static func password(_ value: String) -> String? {
        if value.isEmpty { return String(localized: "err_password_empty") }
        if value.count < minPasswordLength { return String(localized: "err_password_too_short") }
        return nil
    }

    /// Email or handle.
    static func loginIdentifier(_ value: String) -> String? {
        let identifier = value.trimmingCharacters(in: .whitespaces)
        if identifier.isEmpty { return String(localized: "error_empty_fields") }
        if identifier.contains("@") { return email(identifier) }
        if identifier.count < 3 { return String(localized: "error_invalid_handle") }
        return nil
    }

    /// At least first and last name.
    static func fullName(_ value: String) -> String? {
        let words = value.split(whereSeparator: \.isWhitespace)
        return words.count < 2 ? String(localized: "err_name_invalid") : nil
    }

    /// Backend allows 3–20 characters.
    static func handle(_ value: String) -> String? {
        (3...20).contains(value.count) ? nil : String(localized: "error_invalid_handle")
    }

    /// Names such as a collection's: at least 4 characters.
    static func name(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespaces).count < 4 ? String(localized: "error_empty_fields_min_4") : nil
    }

    static func passwordsMatch(_ password: String, _ confirmation: String) -> String? {
        password == confirmation ? nil : String(localized: "err_passwords_not_match")
    }

    /// Users must be at least 13 (by birth year), born 1920 or later.
    static func birthDate(_ date: Date?) -> String? {
        guard let date else { return String(localized: "err_birthday_empty") }
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: Date())
        if year < 1920 { return String(localized: "err_birthday_too_old") }
        if year > currentYear - 13 { return String(localized: "err_birthday_too_young") }
        return nil
    }

    static func otp(_ value: String) -> String? {
        if value.isEmpty { return String(localized: "err_otp_empty") }
        if value.count < otpLength { return String(localized: "err_otp_too_short") }
        if !value.allSatisfy(\.isNumber) { return String(localized: "err_otp_invalid") }
        return nil
    }

    static func firstError(_ results: String?...) -> String? {
        results.lazy.compactMap { $0 }.first
    }
}
