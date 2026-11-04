//
//  WorkSettingsViewModel.swift
//  writepulp
//

import UIKit
import Observation

@MainActor
@Observable
final class WorkSettingsViewModel {
    var title = ""
    var summary = ""
    var language = "en"
    var categoryIds: Set<String> = []
    /// Comma separated, as on the web.
    var tags = ""
    var ageCategory: AgeCategory = .allAges
    var copyright: WorkCopyright = .allRightsReserved
    var isCompleted = false
    var isSupportedWithAI = false
    var isFree = true
    var createCommunity = false
    var requireApproval = false

    /// Just picked, not uploaded yet.
    var newCover: UIImage?
    private(set) var coverPath: String?
    private(set) var coverRemoved = false

    private(set) var publication: WorkDetails.Publication?
    private(set) var categoryGroups: [CategoryGroup] = []
    private(set) var isLoadingCategories = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let workId: String
    private let service: EditorService

    init(workId: String, service: EditorService) {
        self.workId = workId
        self.service = service
    }

    /// Without the rest of its family's languages: an edition per language.
    var languages: [String] {
        let taken = publication?.translations.map(\.language) ?? []
        return ContentLanguage.codes.filter { !taken.contains($0) }
    }

    /// Communities are for works with chapters, and can't be taken back from here.
    var offersCommunity: Bool {
        guard let publication else { return false }
        return !publication.type.isSingleSection && !publication.hasCommunity
    }

    var hasCover: Bool { newCover != nil || coverPath != nil }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSummary: String { summary.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedSummary.isEmpty && !categoryIds.isEmpty && !isSaving
    }

    /// Names of the picked categories, in the order the picker lists them.
    var selectedCategoryNames: [String] {
        categoryGroups.flatMap(\.subCategories).filter { categoryIds.contains($0.id ?? "") }.map(\.name)
    }

    func load() async {
        guard publication == nil else { return }
        do {
            let loaded = try await service.workDetails(id: workId).publication
            title = loaded.title
            summary = loaded.summary ?? ""
            language = loaded.language
            categoryIds = Set(loaded.categories.compactMap(\.id))
            tags = loaded.tags.joined(separator: ", ")
            ageCategory = loaded.ageCategory
            copyright = loaded.copyright
            isCompleted = loaded.isCompleted
            isSupportedWithAI = loaded.isSupportedWithAI
            isFree = loaded.isFree
            coverPath = loaded.coverImg
            publication = loaded
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        categoryGroups = (try? await service.categories()) ?? []
    }

    func toggleCategory(_ id: String) {
        if categoryIds.contains(id) {
            categoryIds.remove(id)
        } else if categoryIds.count < CreateWorkViewModel.categoryLimit {
            categoryIds.insert(id)
        }
    }

    func pickCover(_ image: UIImage) {
        newCover = image
        coverRemoved = false
    }

    func removeCover() {
        newCover = nil
        coverPath = nil
        coverRemoved = true
    }

    /// true when saved and the screen can close.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            var path = coverPath
            if let jpeg = newCover?.compressedJPEG() {
                path = try await service.uploadImage(jpeg, type: .cover)
            }
            let request = WorkUpdateRequest(
                title: trimmedTitle,
                summary: trimmedSummary,
                language: language,
                categoryIds: Array(categoryIds),
                tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                ageCategory: ageCategory,
                copyright: copyright,
                coverImg: path,
                coverRemoved: coverRemoved,
                isCompleted: isCompleted,
                isSupportedWithAI: isSupportedWithAI,
                isFree: isFree,
                createCommunity: offersCommunity && createCommunity,
                requireApproval: offersCommunity && createCommunity && requireApproval
            )
            try await service.updateWork(id: workId, request)
            return true
        } catch APIError.cancelled {
            return false
        } catch {
            toastMessage = error.localizedDescription
            return false
        }
    }
}
