//
//  Downloader.swift
//  writepulp
//

import Foundation

/// Fetches a publication's sections and media into a draft and commits it to the store.
struct Downloader {
    let api: APIClient
    let store: DownloadStore
    var urlSession: URLSession = .shared

    private static let maxConcurrentMedia = 4

    private struct PendingSection {
        let id: String
        let title: String
        let order: Int
    }

    private struct SectionContent {
        let body: String
        var subtitle: String?
        var coverImg: String?
        var pageType = SectionPageType.general.rawValue
        var heroColor: String?
    }

    /// An existing copy is replaced only if at least one section arrives; otherwise it's kept as is.
    func run(
        _ detail: PublicationDetail,
        ownerId: String,
        includeMedia: Bool,
        onProgress: @escaping @MainActor (DownloadProgress) -> Void
    ) async -> DownloadOutcome {
        let pending: [PendingSection]
        do {
            pending = try await pendingSections(of: detail)
        } catch {
            return (error as? APIError)?.isOffline == true ? .offline : .failed
        }
        guard !pending.isEmpty, let draft = try? await store.makeDraft(publicationId: detail.uuid) else { return .failed }

        await onProgress(DownloadProgress(completed: 0, total: pending.count))
        var sections: [DownloadedSection] = []
        for (index, item) in pending.enumerated() {
            if Task.isCancelled { break }
            sections.append(await downloadSection(item, of: detail, into: draft, includeMedia: includeMedia))
            await onProgress(DownloadProgress(completed: index + 1, total: pending.count))
        }

        guard !Task.isCancelled, sections.contains(where: \.isDownloaded) else {
            await store.discard(draft)
            return .failed
        }

        async let cover = fetchMedia(detail.coverImg, into: draft)
        async let avatar = fetchMedia(detail.author.avatarImg, into: draft)
        let manifest = DownloadedPublication(
            id: detail.uuid,
            ownerId: ownerId,
            title: detail.title,
            summary: detail.summary,
            type: detail.type,
            author: .init(uuid: detail.author.uuid, name: detail.author.fullName, avatarFile: await avatar),
            coverFile: await cover,
            sections: sections,
            downloadedAt: Date()
        )
        do {
            try await store.commit(draft, manifest: manifest)
        } catch {
            await store.discard(draft)
            return .failed
        }
        return manifest.isComplete ? .completed : .partial
    }

    // MARK: - Sections

    private func pendingSections(of detail: PublicationDetail) async throws -> [PendingSection] {
        if detail.isSinglePage {
            return [PendingSection(id: detail.uuid, title: detail.title, order: 0)]
        }
        let list = try await api.send(ReaderAPI.chaptersList(publicationId: detail.uuid))
        return list.ordered.map { PendingSection(id: $0.id, title: $0.title, order: $0.order) }
    }

    private func downloadSection(
        _ item: PendingSection,
        of detail: PublicationDetail,
        into draft: DownloadDraft,
        includeMedia: Bool
    ) async -> DownloadedSection {
        guard let content = try? await fetchContent(item, of: detail),
              (try? draft.writeBody(content.body, sectionId: item.id)) != nil else {
            return DownloadedSection(
                id: item.id, title: item.title, order: item.order, subtitle: nil, coverImg: nil, coverFile: nil,
                pageType: SectionPageType.general.rawValue, heroColor: nil, isDownloaded: false, images: [:]
            )
        }

        var images: [String: String] = [:]
        var coverFile: String?
        if includeMedia {
            let paths = Set(EditorDocument.parse(content.body).blocks
                .filter { $0.type == .image || $0.type == .mediaText }
                .compactMap { $0.properties.url?.nilIfBlank })
            images = await fetchMedia(Array(paths), into: draft)
            coverFile = await fetchMedia(content.coverImg, into: draft)
        }

        return DownloadedSection(
            id: item.id,
            title: item.title,
            order: item.order,
            subtitle: content.subtitle,
            coverImg: content.coverImg,
            coverFile: coverFile,
            pageType: content.pageType,
            heroColor: content.heroColor,
            isDownloaded: true,
            images: images
        )
    }

    private func fetchContent(_ item: PendingSection, of detail: PublicationDetail) async throws -> SectionContent? {
        if detail.isSinglePage {
            let article = try await api.send(ReaderAPI.article(publicationId: detail.uuid))
            return article.body.map { SectionContent(body: $0) }
        }
        let chapter = try await api.send(ReaderAPI.chapter(publicationId: detail.uuid, chapterId: item.id))
        return chapter.body.map {
            SectionContent(
                body: $0,
                subtitle: chapter.subtitle,
                coverImg: chapter.coverImg,
                pageType: chapter.pageType.rawValue,
                heroColor: chapter.heroColor
            )
        }
    }

    // MARK: - Media

    /// Downloads a few files at a time; failed ones are left out of the result.
    private func fetchMedia(_ paths: [String], into draft: DownloadDraft) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            var remaining = paths[...]
            var result: [String: String] = [:]

            func enqueueNext() {
                guard let path = remaining.popFirst() else { return }
                group.addTask { (path, await fetchMedia(path, into: draft)) }
            }

            for _ in 0..<Self.maxConcurrentMedia { enqueueNext() }
            while let (path, file) = await group.next() {
                if let file { result[path] = file }
                enqueueNext()
            }
            return result
        }
    }

    private func fetchMedia(_ path: String?, into draft: DownloadDraft) async -> String? {
        guard let path = path?.nilIfBlank else { return nil }
        if let existing = draft.existingMedia(for: path) { return existing }
        guard let url = AppEnvironment.imageURL(path), !url.isFileURL else { return nil }
        do {
            let (temporaryURL, response) = try await urlSession.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                try? FileManager.default.removeItem(at: temporaryURL)
                return nil
            }
            return try draft.storeMedia(at: temporaryURL, for: path)
        } catch {
            return nil
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension APIError {
    var isOffline: Bool {
        if case .noConnection = self { return true }
        return false
    }
}
