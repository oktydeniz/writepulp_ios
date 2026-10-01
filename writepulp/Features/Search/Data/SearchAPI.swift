//
//  SearchAPI.swift
//  writepulp
//

import Foundation

enum SearchAPI {
    static let pageSize = 20

    static func search(
        query: String,
        type: SearchType,
        filters: SearchFilters,
        categorySlug: String?,
        page: Int
    ) -> Endpoint<SearchResultPage> {
        var items = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "sortBy", value: filters.sort.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)"),
        ]
        if let isCompleted = filters.isCompleted {
            items.append(URLQueryItem(name: "isCompleted", value: "\(isCompleted)"))
        }
        if filters.minRating > 0 {
            items.append(URLQueryItem(name: "minRating", value: "\(filters.minRating)"))
        }
        if let readingTime = filters.readingTime {
            items.append(URLQueryItem(name: "readingTimeGroup", value: readingTime.rawValue))
        }
        if let language = filters.language {
            items.append(URLQueryItem(name: "language", value: language))
        }
        if let categorySlug {
            items.append(URLQueryItem(name: "categorySlug", value: categorySlug))
        }
        return Endpoint(path: "search", query: items)
    }
}
