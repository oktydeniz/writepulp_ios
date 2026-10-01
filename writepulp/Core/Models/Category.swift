//
//  Category.swift
//  writepulp
//

import Foundation

/// `data` item of `categories/grouped`: a parent category and its children.
struct CategoryGroup: Decodable, Identifiable {
    struct Category: Decodable, Identifiable, Hashable {
        let id: String?
        let name: String
        let slug: String?
        let translationKey: String?

        var identity: String { id ?? name }
    }

    let parent: Category
    let subCategories: [Category]

    var id: String { parent.identity }
}

enum CategoryAPI {
    static func grouped() -> Endpoint<[CategoryGroup]> {
        Endpoint(path: "categories/grouped")
    }
}
