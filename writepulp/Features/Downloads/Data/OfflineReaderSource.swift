//
//  OfflineReaderSource.swift
//  writepulp
//

import Foundation

/// Downloaded content in the reader's own models, used when the server can't be reached.
protocol OfflineReaderSource: AnyObject, Sendable {
    func chaptersList(publicationId: String) async -> ReaderChaptersList?
    /// nil chapter: the one read last on this device, else the first downloaded one.
    func chapter(publicationId: String, chapterId: String?) async -> ReaderChapter?
    func article(publicationId: String) async -> ReaderArticle?
    func recordProgress(publicationId: String, sectionId: String, percent: Double) async
}

extension DownloadStore: OfflineReaderSource {
    func chaptersList(publicationId: String) async -> ReaderChaptersList? {
        guard let publication = publication(publicationId) else { return nil }
        let sections = publication.readableSections
        guard !sections.isEmpty else { return nil }
        let progress = self.progress(publicationId: publicationId)
        return ReaderChaptersList(
            offlineChapters: sections.map { section in
                ReaderChapterSummary(
                    id: section.id,
                    title: section.title,
                    order: section.order,
                    userProgress: progress[section.id]?.percent,
                    subtitle: section.subtitle,
                    coverImg: coverPath(of: section, publicationId: publicationId),
                    pageType: SectionPageType(rawValue: section.pageType) ?? .general,
                    heroColor: section.heroColor
                )
            }
        )
    }

    func chapter(publicationId: String, chapterId: String?) async -> ReaderChapter? {
        guard let publication = publication(publicationId) else { return nil }
        let sections = publication.readableSections
        let progress = self.progress(publicationId: publicationId)
        let lastRead = progress.filter { entry in sections.contains { $0.id == entry.key } }
            .max { $0.value.readAt < $1.value.readAt }?.key
        guard let section = sections.first(where: { $0.id == (chapterId ?? lastRead) })
                ?? (chapterId == nil ? sections.first : nil),
              let body = localizedBody(publicationId: publicationId, section: section) else { return nil }

        return ReaderChapter(
            offlineId: section.id,
            title: section.title,
            body: body,
            order: section.order,
            userProgress: progress[section.id]?.percent,
            totalChapters: sections.count,
            subtitle: section.subtitle,
            coverImg: coverPath(of: section, publicationId: publicationId),
            pageType: SectionPageType(rawValue: section.pageType) ?? .general,
            heroColor: section.heroColor
        )
    }

    func article(publicationId: String) async -> ReaderArticle? {
        guard let publication = publication(publicationId),
              let section = publication.readableSections.first,
              let body = localizedBody(publicationId: publicationId, section: section) else { return nil }
        let file = { (name: String?) in name.map { self.mediaURL(publicationId: publicationId, file: $0).absoluteString } }

        return ReaderArticle(
            offlineId: section.id,
            title: section.title,
            body: body,
            userProgress: progress(publicationId: publicationId)[section.id]?.percent,
            publication: ReaderPublicationSummary(
                offlineId: publication.id,
                coverImg: file(publication.coverFile),
                title: publication.title,
                summary: publication.summary,
                author: ReaderAuthor(
                    uuid: publication.author.uuid,
                    fullName: publication.author.name,
                    avatarImg: file(publication.author.avatarFile),
                    handle: nil, about: nil, worksCount: nil, followersCount: nil
                )
            )
        )
    }

    // MARK: - Private

    private func coverPath(of section: DownloadedSection, publicationId: String) -> String? {
        section.coverFile.map { mediaURL(publicationId: publicationId, file: $0).absoluteString } ?? section.coverImg
    }

    /// The stored body with image blocks pointing at their saved files. Paths are resolved here,
    /// not at download time, because the app container path changes between installs.
    private func localizedBody(publicationId: String, section: DownloadedSection) -> String? {
        guard let body = body(publicationId: publicationId, sectionId: section.id) else { return nil }
        guard !section.images.isEmpty,
              var document = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any],
              let blocks = document["blocks"] as? [[String: Any]] else { return body }

        document["blocks"] = blocks.map { block -> [String: Any] in
            guard var properties = block["properties"] as? [String: Any],
                  let remote = properties["url"] as? String,
                  let file = section.images[remote] else { return block }
            var block = block
            properties["url"] = mediaURL(publicationId: publicationId, file: file).absoluteString
            block["properties"] = properties
            return block
        }
        guard let data = try? JSONSerialization.data(withJSONObject: document) else { return body }
        return String(data: data, encoding: .utf8) ?? body
    }
}

// MARK: - Offline model builders
// Downloaded content is always readable (the user had access when it was saved), but it's not
// marked as in the library: offline reading earns no coins.

extension ReaderChapterSummary {
    init(
        id: String, title: String, order: Int, userProgress: Double?, subtitle: String?,
        coverImg: String?, pageType: SectionPageType, heroColor: String?
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.isFree = true
        self.userProgress = userProgress
        self.subtitle = subtitle
        self.coverImg = coverImg
        self.pageType = pageType
        self.heroColor = heroColor
    }
}

extension ReaderChaptersList {
    init(offlineChapters chapters: [ReaderChapterSummary]) {
        self.chapters = chapters
        totalChapters = chapters.count
        isInLibrary = false
        libraryItemType = nil
        isOwner = false
        hasFreeAccess = true
    }
}

extension ReaderChapter {
    init(
        offlineId id: String, title: String, body: String, order: Int, userProgress: Double?,
        totalChapters: Int, subtitle: String?, coverImg: String?, pageType: SectionPageType, heroColor: String?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.order = order
        isFree = true
        self.userProgress = userProgress
        self.totalChapters = totalChapters
        isInLibrary = false
        isOwner = false
        hasFreeAccess = true
        self.subtitle = subtitle
        self.coverImg = coverImg
        self.pageType = pageType
        self.heroColor = heroColor
    }
}

extension ReaderArticle {
    init(offlineId id: String, title: String, body: String, userProgress: Double?, publication: ReaderPublicationSummary) {
        self.id = id
        self.title = title
        self.body = body
        self.userProgress = userProgress
        isOwner = false
        hasFreeAccess = true
        isInLibrary = false
        isBookmarked = false
        reaction = nil
        self.publication = publication
    }
}

extension ReaderPublicationSummary {
    init(offlineId uuid: String, coverImg: String?, title: String, summary: String?, author: ReaderAuthor) {
        self.uuid = uuid
        self.coverImg = coverImg
        self.title = title
        self.summary = summary
        self.author = author
        tags = []
        estimateReadTime = 0
        totalViews = 0
        reviewAverage = 0
        categories = []
        publishDate = nil
    }
}
