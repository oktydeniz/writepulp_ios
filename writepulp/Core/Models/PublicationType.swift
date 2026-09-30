//
//  PublicationType.swift
//  writepulp
//

import SwiftUI

enum PublicationType: String, Codable, Hashable, CaseIterable {
    case book = "BOOK"
    case article = "ARTICLE"
    case openBook = "OPEN_BOOK"
    case magazine = "MAGAZINE"
    case script = "SCRIPT"

    /// A type added on the backend later falls back to book instead of failing the whole response.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PublicationType(rawValue: raw.uppercased()) ?? .book
    }

    var label: LocalizedStringKey {
        switch self {
        case .book: "publication_type_book"
        case .article: "publication_type_article"
        case .openBook: "publication_type_open_book"
        case .magazine: "publication_type_magazine"
        case .script: "publication_type_script"
        }
    }
}
