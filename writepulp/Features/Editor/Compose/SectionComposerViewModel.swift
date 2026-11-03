//
//  SectionComposerViewModel.swift
//  writepulp
//

import UIKit
import Observation

/// One section being written: its title, settings and block document, and saving them back
/// in the format of backend docs/editor-document.md.
@MainActor
@Observable
final class SectionComposerViewModel {
    static let titleLimit = 60

    let workId: String
    /// nil until a new section is first saved.
    private(set) var sectionId: String?

    var title = ""
    var document = EditableDocument()
    /// Section fields other than title and body (isFree, magazine hero, revision).
    var draft = SectionDraft.empty
    var themeId = "light"
    var fontId = "default"
    var fontSize = 16.0
    var selectedId: String?
    var coverRemoved = false

    private(set) var workType: PublicationType?
    private(set) var workTitle: String?
    /// true until the first load finishes, so the canvas never shows an empty document first.
    private(set) var isLoading = true
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var lastSavedAt: Date?
    private(set) var uploadingIds: Set<String> = []
    var toastMessage: String?

    private var saved: Snapshot?
    private let service: EditorService

    private struct Snapshot: Equatable {
        let title: String
        let document: EditableDocument
        let draft: SectionDraft
        let reader: [Double]
        let readerIds: [String]
        let coverRemoved: Bool
    }

    init(workId: String, sectionId: String?, service: EditorService) {
        self.workId = workId
        self.sectionId = sectionId
        self.service = service
    }

    // MARK: - State

    var isNew: Bool { sectionId == nil }
    var isDirty: Bool { saved.map { $0 != snapshot } ?? false }
    var isUploading: Bool { !uploadingIds.isEmpty }
    var wordCount: Int { document.blocks.reduce(0) { $0 + $1.wordCount } }
    var readingMinutes: Int { max(1, Int((Double(wordCount) / 200).rounded(.up))) }
    var isMagazine: Bool { workType == .magazine }
    /// Article and script: one piece of content, so the screen talks about "content", not chapters.
    var isSingleSection: Bool { workType?.isSingleSection ?? false }

    var selectedBlock: EditableBlock? {
        guard let selectedId else { return nil }
        return document.blocks.first { $0.id == selectedId }
    }

    private var snapshot: Snapshot {
        Snapshot(
            title: title,
            document: document,
            draft: draft,
            reader: [fontSize],
            readerIds: [themeId, fontId],
            coverRemoved: coverRemoved
        )
    }

    // MARK: - Load

    func load() async {
        guard saved == nil else { return }
        isLoading = true
        defer { isLoading = false }
        async let details = try? service.workDetails(id: workId, page: 0)
        do {
            if let sectionId {
                draft = try await service.section(id: sectionId)
                title = draft.title
                document = try EditableDocument(body: draft.body)
                readReaderSettings()
            } else {
                document = EditableDocument(blocks: [BlockKind.paragraph.makeBlock()])
            }
            if let publication = await details?.publication {
                workType = publication.type
                workTitle = publication.title
            }
            loadError = nil
            saved = snapshot
        } catch APIError.cancelled {
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// `doc.reader`, when the values are ones the reader knows (as the web does).
    private func readReaderSettings() {
        guard let reader = document[field: "reader"]?.objectValue else { return }
        if let id = reader["themeId"]?.stringValue, ReaderTheme.all.contains(where: { $0.id == id }) { themeId = id }
        if let id = reader["fontId"]?.stringValue, ReaderFont.all.contains(where: { $0.id == id }) { fontId = id }
        if let size = reader["fontSize"]?.stringValue.flatMap(Double.init), size > 0 { fontSize = size }
    }

    // MARK: - Blocks

    func index(of id: String) -> Int? { document.blocks.firstIndex { $0.id == id } }

    func update(_ block: EditableBlock) {
        guard let index = index(of: block.id), document.blocks[index] != block else { return }
        document.blocks[index] = block
    }

    /// Inserts after `afterId`, or at the end.
    func insert(_ kind: BlockKind, after afterId: String?) {
        let block = kind.makeBlock()
        if let afterId, let index = index(of: afterId) {
            document.blocks.insert(block, at: index + 1)
        } else {
            document.blocks.append(block)
        }
        selectedId = block.id
    }

    func duplicate(_ id: String) {
        guard let index = index(of: id) else { return }
        let copy = document.blocks[index].duplicated()
        document.blocks.insert(copy, at: index + 1)
        selectedId = copy.id
    }

    func delete(_ id: String) {
        guard let index = index(of: id) else { return }
        document.blocks.remove(at: index)
        if selectedId == id { selectedId = nil }
    }

    func move(_ id: String, by offset: Int) {
        guard let index = index(of: id) else { return }
        let target = index + offset
        guard document.blocks.indices.contains(target) else { return }
        document.blocks.swapAt(index, target)
    }

    /// Uploads right away so the document only ever holds server paths (the backend rejects local URLs).
    func uploadImage(_ image: UIImage, for blockId: String) async {
        guard let jpeg = image.compressedJPEG() else { return }
        uploadingIds.insert(blockId)
        defer { uploadingIds.remove(blockId) }
        do {
            let path = try await service.uploadImage(jpeg)
            guard let index = index(of: blockId) else { return }
            document.blocks[index].setProperty("url", .string(path))
            document.blocks[index].setProperty("isTempUpload", nil)
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    /// Magazine hero image.
    func uploadCover(_ image: UIImage) async {
        guard let jpeg = image.compressedJPEG() else { return }
        uploadingIds.insert("cover")
        defer { uploadingIds.remove("cover") }
        do {
            draft.coverImg = try await service.uploadImage(jpeg)
            coverRemoved = false
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func removeCover() {
        draft.coverImg = nil
        coverRemoved = true
    }

    // MARK: - Save

    /// The document as it will be saved, with the fields the web editor writes.
    func documentForSave() -> EditableDocument {
        var output = document
        if output[field: "id"]?.stringValue?.isEmpty ?? true {
            output[field: "id"] = .string(UUID().uuidString.lowercased())
        }
        output[field: "publicationId"] = .string(workId)
        let header = output.blocks.first { $0.type == BlockKind.header.rawValue }?.content ?? ""
        output[field: "sectionTitle"] = .string(header.isEmpty ? "Chapter" : header)
        output[field: "section"] = .string(sectionId.map { "Chapter \($0)" } ?? "Chapter")
        var reader = output[field: "reader"]?.objectValue ?? [:]
        reader["themeId"] = .string(themeId)
        reader["fontId"] = .string(fontId)
        reader["fontSize"] = .number(fontSize)
        output[field: "reader"] = .object(reader)
        return output
    }

    /// true when saved.
    @discardableResult
    func save() async -> Bool {
        guard !isSaving else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            toastMessage = isSingleSection ? String(localized: "editor_content_title_required") : String(localized: "editor_title_required")
            return false
        }
        guard !isUploading else {
            toastMessage = String(localized: "editor_wait_uploads")
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let output = documentForSave()
            var request = SectionSaveRequest(
                title: trimmedTitle,
                body: try output.encoded(),
                order: draft.order,
                isFree: draft.isFree,
                isForumActive: draft.isForumActive,
                subtitle: draft.subtitle,
                coverImg: draft.coverImg,
                pageType: draft.pageType,
                heroColor: draft.heroColor
            )
            let result: SavedContent
            if let sectionId {
                request.contentRevision = draft.contentRevision
                request.coverRemoved = coverRemoved
                result = try await service.updateSection(id: sectionId, request)
            } else {
                result = try await service.createSection(workId: workId, request)
                sectionId = result.id
            }
            draft.contentRevision = result.contentRevision ?? draft.contentRevision
            draft.title = trimmedTitle
            draft.body = request.body
            title = trimmedTitle
            document = output
            coverRemoved = false
            saved = snapshot
            lastSavedAt = Date()
            toastMessage = String(localized: "editor_saved")
            return true
        } catch APIError.cancelled {
            return false
        } catch APIError.server(let status, _, _, _) where status == 409 {
            toastMessage = String(localized: "editor_conflict")
            return false
        } catch {
            toastMessage = error.localizedDescription
            return false
        }
    }
}
