//
//  EditorModels.swift
//  writepulp
//

import Foundation

/// Backend `PublicationStatus`, used for works and their sections.
enum WorkStatus: String, Codable, Hashable, CaseIterable {
    case draft = "DRAFT"
    case published = "PUBLISHED"
    case hidden = "HIDDEN"
    case removed = "REMOVED"
    case pending = "PENDING"
    case banned = "BANNED"
    case review = "REVIEW"
    case archived = "ARCHIVED"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WorkStatus(rawValue: raw.uppercased()) ?? .draft
    }

    /// The statuses a writer can pick for a section.
    static let sectionChoices: [WorkStatus] = [.draft, .published, .hidden]
}

/// Backend `PublicationPermission`; unknown values are dropped.
enum WorkPermission: String, Decodable, Hashable {
    case editBookInfo = "EDIT_BOOK_INFO"
    case deleteBook = "DELETE_BOOK"
    case archiveBook = "ARCHIVE_BOOK"
    case manageCollaborators = "MANAGE_COLLABORATORS"
    case createSection = "CREATE_SECTION"
    case editSection = "EDIT_SECTION"
    case deleteSection = "DELETE_SECTION"
    case reorderSection = "REORDER_SECTION"
    case publishSection = "PUBLISH_SECTION"
}

/// Decodes a permission list, skipping values this app doesn't know.
private struct PermissionList: Decodable {
    let values: Set<WorkPermission>

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values = Set<WorkPermission>()
        while !container.isAtEnd {
            if let raw = try? container.decode(String.self), let value = WorkPermission(rawValue: raw) {
                values.insert(value)
            }
        }
        self.values = values
    }
}

private extension KeyedDecodingContainer {
    func permissions(_ key: Key) -> Set<WorkPermission> {
        ((try? decodeIfPresent(PermissionList.self, forKey: key)) ?? nil)?.values ?? []
    }
}

// MARK: - Dashboard

/// `GET dashboard/publications`.
struct WriterDashboard: Decodable {
    let publications: Page<WriterWork>
    let totalPublished: Int
    let totalDrafts: Int
    let overallWordCount: Int
    let overallClicks: Int
}

struct WriterWork: Decodable, Identifiable, Hashable {
    let uuid: String
    let title: String
    let status: WorkStatus
    let wordCount: Int
    let totalClicks: Int
    let readingTime: Int
    let sectionCount: Int
    let publicationType: PublicationType
    let updatedAt: String?
    let isOwner: Bool
    let permissions: Set<WorkPermission>

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, title, status, wordCount, totalClicks, readingTime, sectionCount, publicationType,
             updatedAt, isOwner, permissions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try c.decodeIfPresent(WorkStatus.self, forKey: .status) ?? .draft
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        totalClicks = try c.decodeIfPresent(Int.self, forKey: .totalClicks) ?? 0
        readingTime = try c.decodeIfPresent(Int.self, forKey: .readingTime) ?? 0
        sectionCount = try c.decodeIfPresent(Int.self, forKey: .sectionCount) ?? 0
        publicationType = try c.decodeIfPresent(PublicationType.self, forKey: .publicationType) ?? .book
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        permissions = c.permissions(.permissions)
    }
}

// MARK: - Work manager

/// `GET dashboard/publications/{id}/details`.
struct WorkDetails: Decodable {
    struct Publication: Decodable {
        let uuid: String
        let title: String
        let summary: String?
        let coverImg: String?
        let type: PublicationType
        let status: WorkStatus
        let isFree: Bool
        /// Lowercase code, e.g. "tr".
        let language: String
        /// Set on a translation.
        let originalPublicationId: String?
        /// The rest of its language family, whatever their status.
        let translations: [WorkTranslation]
        let categories: [CategoryGroup.Category]
        let tags: [String]
        let ageCategory: AgeCategory
        let copyright: WorkCopyright
        let isCompleted: Bool
        let isSupportedWithAI: Bool
        let hasCommunity: Bool
    }

    let publication: Publication
    let collaborators: [WorkCollaborator]
    let sections: Page<WorkSection>
    let isOwner: Bool
    let permissions: Set<WorkPermission>

    enum CodingKeys: String, CodingKey {
        case publication, sections, isOwner, permissions
        case collaborators = "collaborations"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        publication = try c.decode(Publication.self, forKey: .publication)
        collaborators = try c.decodeIfPresent([WorkCollaborator].self, forKey: .collaborators) ?? []
        sections = try c.decode(Page<WorkSection>.self, forKey: .sections)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        permissions = c.permissions(.permissions)
    }

    func can(_ permission: WorkPermission) -> Bool { isOwner || permissions.contains(permission) }
}

extension WorkDetails.Publication {
    enum CodingKeys: String, CodingKey {
        case uuid, title, summary, coverImg, type, status, isFree, originalPublicationId, translations, categories,
             tags, ageCategory, copyright, isCompleted, isSupportedWithAI, hasCommunity
        case language = "lng"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        coverImg = try c.decodeIfPresent(String.self, forKey: .coverImg)
        type = try c.decodeIfPresent(PublicationType.self, forKey: .type) ?? .book
        status = try c.decodeIfPresent(WorkStatus.self, forKey: .status) ?? .draft
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
        originalPublicationId = try c.decodeIfPresent(String.self, forKey: .originalPublicationId)
        translations = try c.decodeIfPresent([WorkTranslation].self, forKey: .translations) ?? []
        categories = try c.decodeIfPresent([CategoryGroup.Category].self, forKey: .categories) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        ageCategory = (try? c.decodeIfPresent(AgeCategory.self, forKey: .ageCategory)) ?? .allAges
        copyright = (try? c.decodeIfPresent(WorkCopyright.self, forKey: .copyright)) ?? .allRightsReserved
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isSupportedWithAI = try c.decodeIfPresent(Bool.self, forKey: .isSupportedWithAI) ?? false
        hasCommunity = try c.decodeIfPresent(Bool.self, forKey: .hasCommunity) ?? false
    }
}

/// Another language's edition of a work. Readers only get published ones; the owner gets them all.
struct WorkTranslation: Decodable, Identifiable, Hashable {
    let uuid: String
    /// Lowercase code, e.g. "tr".
    let language: String
    let title: String
    let coverImg: String?
    let status: WorkStatus

    var id: String { uuid }
}

/// Backend `CollaboratorRole`.
enum CollaboratorRole: String, Codable, Hashable {
    case coAuthor = "CO_AUTHOR"
    case editor = "EDITOR"
    case translator = "TRANSLATOR"
    case contributor = "CONTRIBUTOR"
    case viewerAuthor = "VIEWER_AUTHOR"

    /// The roles an owner can give, as on the web.
    static let assignable: [CollaboratorRole] = [.coAuthor, .editor, .translator, .viewerAuthor]
}

/// A team member; `uuid` is the user's id.
struct WorkCollaborator: Decodable, Identifiable, Hashable {
    let uuid: String
    let role: CollaboratorRole
    let avatarImg: String?
    let handle: String
    let fullName: String

    var id: String { uuid }
}

/// `POST publications/{id}/collaborators/invite`.
struct CollaboratorInviteRequest: Encodable {
    let targetUserHandle: String
    let role: CollaboratorRole
}

/// `POST publications/{id}/translations`.
struct TranslationCreateRequest: Encodable {
    let title: String
    /// Lowercase code, e.g. "tr".
    let language: String
}

/// `PUT publications/{id}`. Price and status are left out, so the backend keeps them.
struct WorkUpdateRequest: Encodable {
    let title: String
    let summary: String
    let language: String
    let categoryIds: [String]
    let tags: [String]
    let ageCategory: AgeCategory
    let copyright: WorkCopyright
    let coverImg: String?
    let coverRemoved: Bool
    let isCompleted: Bool
    let isSupportedWithAI: Bool
    let isFree: Bool
    let createCommunity: Bool
    let requireApproval: Bool
}

struct SectionOrderRequest: Encodable {
    let sectionId: String
    let newOrder: Int
}

struct WorkSection: Decodable, Identifiable, Hashable {
    let uuid: String
    let title: String
    var order: Int
    let wordCount: Int
    let readingTime: Int
    var status: WorkStatus
    var isLocked: Bool
    let isFree: Bool
    let updatedAt: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, title, order, wordCount, readingTime, status, isLocked, isFree, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        readingTime = try c.decodeIfPresent(Int.self, forKey: .readingTime) ?? 0
        status = try c.decodeIfPresent(WorkStatus.self, forKey: .status) ?? .draft
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - Section editing

/// `GET sections/writer-detail/{id}`.
struct SectionDraftResponse: Decodable {
    let section: SectionDraft
}

/// The section fields the editor loads and saves back.
struct SectionDraft: Decodable, Equatable {
    var title: String
    var body: String
    var order: Int?
    var isFree: Bool
    var isForumActive: Bool
    var subtitle: String?
    var coverImg: String?
    /// Backend `SectionPageType`, kept as text so new values survive a save.
    var pageType: String?
    var heroColor: String?
    var contentRevision: Int?

    static let empty = SectionDraft(
        title: "", body: "", order: nil, isFree: false, isForumActive: false,
        subtitle: nil, coverImg: nil, pageType: nil, heroColor: nil, contentRevision: nil
    )
}

extension SectionDraft {
    enum CodingKeys: String, CodingKey {
        case title, body, order, isFree, isForumActive, subtitle, coverImg, pageType, heroColor, contentRevision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        order = try c.decodeIfPresent(Int.self, forKey: .order)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        isForumActive = try c.decodeIfPresent(Bool.self, forKey: .isForumActive) ?? false
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        coverImg = try c.decodeIfPresent(String.self, forKey: .coverImg)
        pageType = try c.decodeIfPresent(String.self, forKey: .pageType)
        heroColor = try c.decodeIfPresent(String.self, forKey: .heroColor)
        contentRevision = try c.decodeIfPresent(Int.self, forKey: .contentRevision)
    }
}

/// `POST sections/{pubId}` (create) body; `PUT sections/{id}` adds the update-only fields.
struct SectionSaveRequest: Encodable {
    let title: String
    let body: String
    let order: Int?
    let isFree: Bool
    let isForumActive: Bool
    let subtitle: String?
    let coverImg: String?
    let pageType: String?
    let heroColor: String?
    /// Update only: the revision the editor loaded; a stale one gets 409.
    var contentRevision: Int?
    /// Update only: true clears the cover.
    var coverRemoved: Bool?
}

/// Answer of section create/update and publication create.
struct SavedContent: Decodable {
    let id: String
    let contentRevision: Int?
}

// MARK: - New work

enum AgeCategory: String, Codable, CaseIterable, Hashable {
    case allAges = "ALL_AGES"
    case child = "CHILD"
    case teenager = "TEENAGER"
    case adult = "ADULT"
}

/// Backend `Copyright`; the reader side has its own decode-only `Copyright`.
enum WorkCopyright: String, Codable, CaseIterable, Hashable {
    case allRightsReserved = "ALL_RIGHTS_RESERVED"
    case publicDomain = "PUBLIC_DOMAIN"
    case ccBy = "CC_BY"
    case ccByNc = "CC_BY_NC"
    case ccByNcNd = "CC_BY_NC_ND"
    case ccBySa = "CC_BY_SA"
    case ccByNd = "CC_BY_ND"
    case ccByNcSa = "CC_BY_NC_SA"
}

/// `POST publications`.
struct WorkCreateRequest: Encodable {
    let title: String
    let type: PublicationType
    /// Lowercase code, e.g. "tr".
    let language: String
    let categoryIds: [String]
    let summary: String
    let coverImg: String?
    let ageCategory: AgeCategory
    let copyright: WorkCopyright
    let tags: [String]
    let isSupportedWithAI: Bool
    let isFree: Bool
    var status: WorkStatus = .draft
}
