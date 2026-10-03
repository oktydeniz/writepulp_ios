//
//  DownloadModels.swift
//  writepulp
//

import Foundation

/// Manifest of a publication saved for offline reading. Bodies and media live next to it on disk.
struct DownloadedPublication: Codable, Identifiable, Hashable {
    struct Author: Codable, Hashable {
        let uuid: String
        let name: String
        let avatarFile: String?
    }

    let id: String
    /// Account that downloaded it; other accounts never see it.
    let ownerId: String
    let title: String
    let summary: String
    let type: PublicationType
    let author: Author
    let coverFile: String?
    let sections: [DownloadedSection]
    let downloadedAt: Date

    /// False when some sections failed; the rest is still readable.
    var isComplete: Bool { sections.allSatisfy(\.isDownloaded) }
    var readableSections: [DownloadedSection] {
        sections.filter(\.isDownloaded).sorted { $0.order < $1.order }
    }
}

struct DownloadedSection: Codable, Identifiable, Hashable {
    /// For articles and scripts this is the publication id: they have a single section.
    let id: String
    let title: String
    let order: Int
    let subtitle: String?
    let coverImg: String?
    let coverFile: String?
    let pageType: String
    let heroColor: String?
    let isDownloaded: Bool
    /// Remote image path as written in the body → saved file name.
    let images: [String: String]
}

/// Last reading position of a downloaded section on this device.
struct LocalProgress: Codable {
    var percent: Double
    var readAt: Date
}

enum DownloadOutcome {
    case completed
    /// Some sections couldn't be fetched; what did arrive was saved.
    case partial
    case failed
    case offline
}

struct DownloadProgress: Equatable {
    let completed: Int
    let total: Int

    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}
