//
//  PublicationSummary.swift
//  writepulp
//

import Foundation

/// The card fields of a full publication response (profile works, library items…).
struct PublicationSummary: Decodable, Identifiable {
    struct Author: Decodable {
        let fullName: String
    }

    let uuid: String
    let title: String
    let coverImg: String?
    let type: PublicationType
    let author: Author
    let sectionCount: Int?
    let reviewAverage: Double?
    let totalClicked: Int?
    let estimatedReadingTime: Int?

    var id: String { uuid }

    var cardContent: PublicationCardContent {
        PublicationCardContent(
            id: uuid,
            title: title,
            coverImg: coverImg,
            type: type,
            authorName: author.fullName,
            rating: reviewAverage ?? 0,
            views: totalClicked ?? 0,
            sectionCount: sectionCount,
            readTimeMinutes: estimatedReadingTime
        )
    }
}
