//
//  ReaderModels.swift
//  writepulp
//

import Foundation

enum SectionPageType: String, Decodable {
    case editorial = "EDITORIAL"
    case feature = "FEATURE"
    case poetry = "POETRY"
    case interview = "INTERVIEW"
    case scene = "SCENE"
    case general = "GENERAL"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SectionPageType(rawValue: raw) ?? .general
    }

    var titleKey: String {
        "reader_page_type_\(rawValue.lowercased())"
    }
}

/// Access flags shared by the chapter list and a chapter's content.
protocol ReaderAccess {
    var isOwner: Bool { get }
    var isInLibrary: Bool { get }
    var hasFreeAccess: Bool { get }
}

extension ReaderAccess {
    /// Whole-publication access, or the chapter's own free preview.
    func canAccess(_ chapter: ReaderChapterSummary) -> Bool {
        isOwner || isInLibrary || hasFreeAccess || chapter.isFree
    }

    /// Reading time only earns coins for publications in the library that aren't the reader's own.
    var earnsCoins: Bool { isInLibrary && !isOwner }
}

struct ReaderChapterSummary: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let order: Int
    let isFree: Bool
    let userProgress: Double?
    let subtitle: String?
    let coverImg: String?
    let pageType: SectionPageType
    let heroColor: String?

    enum CodingKeys: String, CodingKey {
        case id, title, order, isFree, userProgress, subtitle, coverImg, pageType, heroColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        userProgress = try c.decodeIfPresent(Double.self, forKey: .userProgress)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        coverImg = try c.decodeIfPresent(String.self, forKey: .coverImg)
        pageType = try c.decodeIfPresent(SectionPageType.self, forKey: .pageType) ?? .general
        heroColor = try c.decodeIfPresent(String.self, forKey: .heroColor)
    }
}

/// `data` of `sections/reader/{id}/chapters-list`.
struct ReaderChaptersList: Decodable, ReaderAccess {
    let totalChapters: Int
    let isInLibrary: Bool
    let libraryItemType: String?
    let isOwner: Bool
    let hasFreeAccess: Bool
    let chapters: [ReaderChapterSummary]

    enum CodingKeys: String, CodingKey {
        case totalChapters, isInLibrary, libraryItemType, isOwner, hasFreeAccess, chapters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chapters = try c.decodeIfPresent([ReaderChapterSummary].self, forKey: .chapters) ?? []
        totalChapters = try c.decodeIfPresent(Int.self, forKey: .totalChapters) ?? chapters.count
        isInLibrary = try c.decodeIfPresent(Bool.self, forKey: .isInLibrary) ?? false
        libraryItemType = try c.decodeIfPresent(String.self, forKey: .libraryItemType)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        hasFreeAccess = try c.decodeIfPresent(Bool.self, forKey: .hasFreeAccess) ?? false
    }

    /// Chapters in reading order.
    var ordered: [ReaderChapterSummary] { chapters.sorted { $0.order < $1.order } }
}

/// `data` of `sections/reader/{id}/chapters/{chapterId}` and `.../current-chapter`.
struct ReaderChapter: Decodable, Identifiable, ReaderAccess {
    let id: String
    let title: String
    let body: String?
    let order: Int
    let isFree: Bool
    let userProgress: Double?
    let totalChapters: Int
    let isInLibrary: Bool
    let isOwner: Bool
    let hasFreeAccess: Bool
    let subtitle: String?
    let coverImg: String?
    let pageType: SectionPageType
    let heroColor: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, order, isFree, userProgress, totalChapters, isInLibrary, isOwner,
             hasFreeAccess, subtitle, coverImg, pageType, heroColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        userProgress = try c.decodeIfPresent(Double.self, forKey: .userProgress)
        totalChapters = try c.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 0
        isInLibrary = try c.decodeIfPresent(Bool.self, forKey: .isInLibrary) ?? false
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        hasFreeAccess = try c.decodeIfPresent(Bool.self, forKey: .hasFreeAccess) ?? false
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        coverImg = try c.decodeIfPresent(String.self, forKey: .coverImg)
        pageType = try c.decodeIfPresent(SectionPageType.self, forKey: .pageType) ?? .general
        heroColor = try c.decodeIfPresent(String.self, forKey: .heroColor)
    }

    var isAccessible: Bool { isOwner || isInLibrary || hasFreeAccess || isFree }
}

struct ReaderAuthor: Decodable {
    let uuid: String
    let fullName: String
    let avatarImg: String?
    let handle: String?
    let about: String?
    let worksCount: Int?
    let followersCount: Int?
}

struct ReaderCategory: Decodable, Hashable {
    let name: String
    let slug: String
}

struct ReaderPublicationSummary: Decodable {
    let uuid: String
    let coverImg: String?
    let title: String
    let summary: String?
    let author: ReaderAuthor
    let tags: [String]
    let estimateReadTime: Int
    let totalViews: Int
    let reviewAverage: Double
    let categories: [ReaderCategory]
    let publishDate: String?

    enum CodingKeys: String, CodingKey {
        case uuid, coverImg, title, summary, author, tags, estimateReadTime, totalViews,
             reviewAverage, categories, publishDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        coverImg = try c.decodeIfPresent(String.self, forKey: .coverImg)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        author = try c.decode(ReaderAuthor.self, forKey: .author)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        estimateReadTime = try c.decodeIfPresent(Int.self, forKey: .estimateReadTime) ?? 0
        totalViews = try c.decodeIfPresent(Int.self, forKey: .totalViews) ?? 0
        reviewAverage = try c.decodeIfPresent(Double.self, forKey: .reviewAverage) ?? 0
        categories = try c.decodeIfPresent([ReaderCategory].self, forKey: .categories) ?? []
        // Instants come as ISO strings, or as epoch seconds when the server's mapper writes numbers.
        if let text = try? c.decodeIfPresent(String.self, forKey: .publishDate) {
            publishDate = text
        } else if let seconds = try? c.decodeIfPresent(Double.self, forKey: .publishDate) {
            publishDate = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds))
        } else {
            publishDate = nil
        }
    }
}

/// `data` of `sections/{publicationId}/article`: the single page of an article or script.
struct ReaderArticle: Decodable, Identifiable, ReaderAccess {
    let id: String
    let title: String
    let body: String?
    let userProgress: Double?
    let isOwner: Bool
    let hasFreeAccess: Bool
    let isInLibrary: Bool
    let isBookmarked: Bool
    let reaction: ReactionType?
    let publication: ReaderPublicationSummary

    enum CodingKeys: String, CodingKey {
        case id, title, body, userProgress, isOwner, hasFreeAccess, isInLibrary, isBookmarked, reaction, publication
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body)
        userProgress = try c.decodeIfPresent(Double.self, forKey: .userProgress)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        hasFreeAccess = try c.decodeIfPresent(Bool.self, forKey: .hasFreeAccess) ?? false
        isInLibrary = try c.decodeIfPresent(Bool.self, forKey: .isInLibrary) ?? false
        isBookmarked = try c.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        reaction = try? c.decodeIfPresent(ReactionType.self, forKey: .reaction)
        publication = try c.decode(ReaderPublicationSummary.self, forKey: .publication)
    }
}

// MARK: - Reading sessions (coins)

struct ReadingSession: Decodable {
    let sessionId: String
    let coinsEarned: Int?
    let dailyTotal: Int?
}

struct SessionHeartbeatRequest: Encodable {
    let sectionId: String
    let elapsedSeconds: Int
    let deviceType = "MOBILE"
}

// MARK: - Reactions

enum ReactionType: String, Codable, CaseIterable {
    case like = "LIKE"
    case love = "LOVE"
    case laugh = "LAUGH"
    case angry = "ANGRY"
    case sad = "SAD"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = ReactionType(rawValue: raw.uppercased()) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: raw))
        }
        self = value
    }
}

struct SectionReaction: Decodable {
    struct User: Decodable { let uuid: String }

    let id: String
    let user: User
    let type: ReactionType
}

struct AddReactionRequest: Encodable {
    let type: ReactionType
}
