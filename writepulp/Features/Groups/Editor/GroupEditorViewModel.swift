//
//  GroupEditorViewModel.swift
//  writepulp
//

import Observation
import UIKit

/// Create or edit a community.
@MainActor
@Observable
final class GroupEditorViewModel {
    static let maxCategories = 8

    /// nil: creating a new community.
    let groupId: String?
    private let publicationId: String?

    var name = ""
    var description = ""
    var isPrivate = false
    var restrictedMessaging = false
    var tagsText = ""
    var rules: [String] = []
    var newRule = ""
    var newAvatar: UIImage? {
        didSet { if newAvatar != nil { isAvatarRemoved = false } }
    }
    private(set) var remoteAvatar: String?
    private(set) var isAvatarRemoved = false
    private(set) var categoryIds: Set<String> = []
    private(set) var categoryGroups: [CategoryGroup] = []
    private(set) var isLoading = false
    private(set) var isLoadingCategories = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var isPickingCategories = false
    var toastMessage: String?

    private let service: GroupsService
    /// Names of the community's categories, for ones missing from the picker list.
    private var knownCategoryNames: [String: String] = [:]

    init(groupId: String?, publicationId: String? = nil, service: GroupsService) {
        self.groupId = groupId
        self.publicationId = publicationId
        self.service = service
    }

    var isEditing: Bool { groupId != nil }
    var hasAvatar: Bool { newAvatar != nil || (remoteAvatar != nil && !isAvatarRemoved) }

    var selectedCategoryNames: [String] {
        let lookup = knownCategoryNames.merging(
            categoryGroups.flatMap { [$0.parent] + $0.subCategories }.compactMap { category in
                category.id.map { ($0, category.name) }
            },
            uniquingKeysWith: { _, new in new }
        )
        return categoryIds.compactMap { lookup[$0] }.sorted()
    }

    /// Comma separated, without "#", duplicates or blanks.
    var tags: Set<String> {
        Set(tagsText.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        }.filter { !$0.isEmpty })
    }

    // MARK: - Loading

    func load() async {
        guard let groupId, name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await service.detail(id: groupId)
            name = detail.name
            description = detail.description ?? ""
            isPrivate = detail.isPrivate
            restrictedMessaging = detail.restrictedMessaging
            tagsText = detail.tags.sorted().joined(separator: ", ")
            rules = detail.rules
            remoteAvatar = detail.groupAvatar
            categoryIds = Set(detail.categories.compactMap(\.id))
            for category in detail.categories {
                if let id = category.id { knownCategoryNames[id] = category.name }
            }
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openCategoryPicker() async {
        isPickingCategories = true
        guard categoryGroups.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categoryGroups = try await service.categoryGroups()
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    // MARK: - Editing

    func toggleCategory(_ id: String) {
        if categoryIds.contains(id) {
            categoryIds.remove(id)
        } else if categoryIds.count >= Self.maxCategories {
            toastMessage = "max_category_limit".localized(Self.maxCategories)
        } else {
            categoryIds.insert(id)
        }
    }

    func addRule() {
        let rule = newRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty else { return }
        rules.append(rule)
        newRule = ""
    }

    func removeAvatar() {
        newAvatar = nil
        isAvatarRemoved = true
    }

    // MARK: - Saving

    /// The community id on success.
    func save() async -> String? {
        if let error = FormValidator.name(name) {
            toastMessage = error
            return nil
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            toastMessage = String(localized: "error_empty_fields")
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        do {
            var avatar = isAvatarRemoved ? nil : remoteAvatar
            if let newAvatar {
                guard let jpeg = newAvatar.compressedJPEG(maxDimension: 512) else {
                    toastMessage = String(localized: "the_image_could_not_be_processed")
                    return nil
                }
                avatar = try await service.uploadImage(jpeg, type: .icon)
            }
            var form = GroupForm(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                isPrivate: isPrivate,
                restrictedMessaging: restrictedMessaging,
                groupAvatar: avatar,
                categoryIds: categoryIds,
                tags: tags,
                rules: rules
            )
            if let groupId {
                form.isAvatarRemoved = isAvatarRemoved && newAvatar == nil
                try await service.update(id: groupId, form)
                return groupId
            }
            form.publicationId = publicationId
            return try await service.create(form)
        } catch {
            toastMessage = error.localizedDescription
            return nil
        }
    }
}
