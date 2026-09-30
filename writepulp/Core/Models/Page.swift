//
//  Page.swift
//  writepulp
//

import Foundation

/// Spring Data page: `data` of every paginated endpoint.
struct Page<Item: Decodable>: Decodable {
    let content: [Item]
    let number: Int
    let last: Bool
    let totalElements: Int?
}
