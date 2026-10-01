//
//  PocketModels.swift
//  writepulp
//

import SwiftUI

enum LibraryStatus: String, Codable, CaseIterable, Hashable {
    case reading = "READING"
    case completed = "COMPLETED"
    case owned = "OWNED"
    case archived = "ARCHIVED"

    var title: LocalizedStringKey {
        switch self {
        case .reading: "pocket_tab_reading"
        case .completed: "pocket_tab_completed"
        case .owned: "pocket_tab_owned"
        case .archived: "pocket_tab_archived"
        }
    }

    var systemImage: String {
        switch self {
        case .reading: "book.fill"
        case .completed: "checkmark"
        case .owned: "bookmark.fill"
        case .archived: "archivebox.fill"
        }
    }
}

struct LibraryItem: Decodable, Identifiable {
    let publication: PublicationSummary
    let lastChapterUUID: String?
    var status: LibraryStatus
    var progressPercent: Double

    var id: String { publication.uuid }
}

/// `data` of `library/me`.
struct Library: Decodable {
    let lastReadItem: LibraryItem?
    let groups: [LibraryStatus: [LibraryItem]]

    private enum CodingKeys: String, CodingKey {
        case lastReadItem, groupedItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastReadItem = try container.decodeIfPresent(LibraryItem.self, forKey: .lastReadItem)
        // Enum-keyed dictionaries don't decode from JSON objects, so go through String keys.
        let raw = try container.decodeIfPresent([String: [LibraryItem]].self, forKey: .groupedItems) ?? [:]
        groups = Dictionary(uniqueKeysWithValues: raw.compactMap { key, items in
            LibraryStatus(rawValue: key).map { ($0, items) }
        })
    }
}
