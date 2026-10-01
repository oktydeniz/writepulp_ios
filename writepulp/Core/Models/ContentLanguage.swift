//
//  ContentLanguage.swift
//  writepulp
//

import Foundation

/// Languages a publication can be written in, as backend codes.
enum ContentLanguage {
    static let codes = [
        "tr", "en", "de", "fr", "es", "it", "pt", "ru", "zh",
        "ja", "hi", "ko", "id", "vi", "pl", "th", "tl", "uk",
    ]

    /// Name in the app's current language, e.g. "Türkçe" / "Turkish".
    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code.uppercased()
    }
}
