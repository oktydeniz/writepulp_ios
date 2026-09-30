//
//  Formatters.swift
//  writepulp
//

import Foundation

enum Formatters {
    /// Backend timestamps (Instant, with or without fractional seconds) and plain dates (LocalDate).
    static func date(fromISO value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFractional.date(from: value) ?? iso.date(from: value) ?? localDate.date(from: value)
    }

    /// "1 Sep 2026" in the current locale.
    static func mediumDate(_ value: String?) -> String {
        guard let date = date(fromISO: value) else { return value ?? "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private static let localDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "just now", "5 min ago", "3 d ago"… as on Android.
    static func timeAgo(_ value: String?, now: Date = Date()) -> String {
        guard let date = date(fromISO: value) else { return "" }
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return String(localized: "time_just_now")
        case ..<3_600: return "time_minutes_ago".localized(seconds / 60)
        case ..<86_400: return "time_hours_ago".localized(seconds / 3_600)
        case ..<2_592_000: return "time_days_ago".localized(seconds / 86_400)
        case ..<31_536_000: return "time_months_ago".localized(seconds / 2_592_000)
        default: return "time_years_ago".localized(seconds / 31_536_000)
        }
    }

    /// "7m" / "2h", nil when unknown.
    static func readTime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes < 60 ? "\(minutes)m" : "\(Int((Double(minutes) / 60).rounded()))h"
    }

    static func compactCount(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName))
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso = ISO8601DateFormatter()
}
