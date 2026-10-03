//
//  PagedList.swift
//  writepulp
//

import Foundation

/// Items accumulated from consecutive `Page` responses.
struct PagedList<Item: Decodable> {
    private(set) var items: [Item] = []
    private(set) var nextPage = 0
    private(set) var hasMore = true
    private(set) var hasLoaded = false
    /// From the latest page, when the endpoint reports it.
    private(set) var totalElements: Int?

    var isEmpty: Bool { items.isEmpty }

    mutating func apply(_ page: Page<Item>, replacing: Bool) {
        applyFiltered(page, content: page.content, replacing: replacing)
    }

    fileprivate mutating func applyFiltered(_ page: Page<Item>, content: [Item], replacing: Bool) {
        items = replacing ? content : items + content
        nextPage = replacing ? 1 : nextPage + 1
        hasMore = !page.last
        hasLoaded = true
        totalElements = page.totalElements ?? totalElements
    }

    mutating func update(where predicate: (Item) -> Bool, _ change: (inout Item) -> Void) {
        for index in items.indices where predicate(items[index]) {
            change(&items[index])
        }
    }

    mutating func removeAll(where predicate: (Item) -> Bool) {
        items.removeAll(where: predicate)
    }
}

extension PagedList where Item: Identifiable {
    /// The server can repeat an item across pages (unstable sort); a repeated id confuses `ForEach`.
    mutating func apply(_ page: Page<Item>, replacing: Bool) {
        var seen = replacing ? Set<Item.ID>() : Set(items.map(\.id))
        let fresh = page.content.filter { seen.insert($0.id).inserted }
        applyFiltered(page, content: fresh, replacing: replacing)
    }
}
