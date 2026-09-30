//
//  AppEnvironment.swift
//  writepulp
//

import Foundation

/// Per-build values from Config/<Configuration>.xcconfig, exposed through Info.plist.
enum AppEnvironment {
    static let name = string("Name")
    static let apiBaseURL = url("APIBaseURL")
    static let cdnBaseURL = url("CDNBaseURL")
    static let webSocketURL = url("WebSocketURL")
    static let isDevMode = string("DevMode") == "YES"
    /// Crashlytics collection; Info.plist keeps it off until this turns it on at launch.
    static let isCrashReportingEnabled = string("CrashReporting") == "YES"

    /// Backend image paths are relative to the CDN; absolute URLs are used as-is.
    static func imageURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") || path.hasPrefix("file://") { return URL(string: path) }
        return URL(string: path, relativeTo: cdnBaseURL)?.absoluteURL
    }

    private static let values = Bundle.main.object(forInfoDictionaryKey: "AppEnvironment") as? [String: String] ?? [:]

    private static func string(_ key: String) -> String {
        guard let value = values[key], !value.isEmpty else {
            fatalError("AppEnvironment.\(key) missing — check Config/*.xcconfig and Info.plist")
        }
        return value
    }

    private static func url(_ key: String) -> URL {
        guard let url = URL(string: string(key)) else {
            fatalError("AppEnvironment.\(key) is not a valid URL")
        }
        return url
    }
}
