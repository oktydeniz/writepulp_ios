//
//  CreateWorkViewModel.swift
//  writepulp
//

import UIKit
import Observation

@MainActor
@Observable
final class CreateWorkViewModel {
    static let titleLimit = 120
    static let summaryLimit = 500
    static let categoryLimit = 5

    var type: PublicationType
    var title = ""
    var summary = ""
    var language: String
    var categoryIds: Set<String> = []
    var ageCategory: AgeCategory = .allAges
    var copyright: WorkCopyright = .allRightsReserved
    /// Comma separated, as on the web.
    var tags = ""
    var isSupportedWithAI = false
    var isFree = true
    var cover: UIImage?

    private(set) var categoryGroups: [CategoryGroup] = []
    private(set) var isLoadingCategories = false
    private(set) var isSaving = false
    var toastMessage: String?

    private let service: EditorService

    init(type: PublicationType, service: EditorService) {
        self.type = type
        self.service = service
        let appLanguage = AppPreferences.currentLanguageCode
        language = ContentLanguage.codes.contains(appLanguage) ? appLanguage : "en"
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSummary: String { summary.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool {
        !trimmedTitle.isEmpty && !trimmedSummary.isEmpty && !categoryIds.isEmpty && !isSaving
    }

    /// Names of the picked categories, in the order the picker lists them.
    var selectedCategoryNames: [String] {
        categoryGroups.flatMap(\.subCategories).filter { categoryIds.contains($0.id ?? "") }.map(\.name)
    }

    func loadCategories() async {
        guard categoryGroups.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        categoryGroups = (try? await service.categories()) ?? []
    }

    func toggleCategory(_ id: String) {
        if categoryIds.contains(id) {
            categoryIds.remove(id)
        } else if categoryIds.count < Self.categoryLimit {
            categoryIds.insert(id)
        }
    }

    /// Returns the new work's id.
    func submit() async -> String? {
        guard canSubmit else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            var coverPath: String?
            if let jpeg = cover?.compressedJPEG() {
                coverPath = try await service.uploadImage(jpeg, type: .cover)
            }
            let request = WorkCreateRequest(
                title: trimmedTitle,
                type: type,
                language: language,
                categoryIds: Array(categoryIds),
                summary: trimmedSummary,
                coverImg: coverPath,
                ageCategory: ageCategory,
                copyright: copyright,
                tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                isSupportedWithAI: isSupportedWithAI,
                isFree: isFree
            )
            return try await service.createWork(request)
        } catch APIError.cancelled {
            return nil
        } catch {
            toastMessage = error.localizedDescription
            return nil
        }
    }
}
