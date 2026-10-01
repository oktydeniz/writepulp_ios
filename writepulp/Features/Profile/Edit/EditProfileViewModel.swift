//
//  EditProfileViewModel.swift
//  writepulp
//

import SwiftUI
import Observation

@MainActor
@Observable
final class EditProfileViewModel {
    static let maxNameLength = 60
    static let maxAboutLength = 1000

    var draft: EditableProfile?
    /// Picked from the library, not uploaded yet.
    private(set) var pickedImage: UIImage?
    private(set) var isAvatarRemoved = false
    var birthDate: Date?
    /// The birth date can only be set once.
    private(set) var canEditBirthDate = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?
    var didSave = false

    private var original: EditableProfile?
    private let service: ProfileService

    init(service: ProfileService) {
        self.service = service
    }

    var hasAvatar: Bool {
        pickedImage != nil || (!isAvatarRemoved && !(draft?.avatarImg?.isEmpty ?? true))
    }

    var hasChanges: Bool {
        draft != original || pickedImage != nil || isAvatarRemoved || (canEditBirthDate && birthDate != nil)
    }

    func load() async {
        guard draft == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await service.editableProfile()
            draft = profile
            original = profile
            canEditBirthDate = profile.birthDate?.isEmpty ?? true
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPickedImage(_ image: UIImage) {
        pickedImage = image
        isAvatarRemoved = false
    }

    func removeAvatar() {
        pickedImage = nil
        isAvatarRemoved = true
    }

    func save() async {
        guard var draft else { return }
        if let error = validate(draft) {
            errorMessage = error
            return
        }
        if canEditBirthDate, let birthDate {
            draft.birthDate = Self.birthDateFormatter.string(from: birthDate)
        }
        let avatar: ProfileService.AvatarChange = if let pickedImage {
            .replace(pickedImage)
        } else if isAvatarRemoved {
            .remove
        } else {
            .keep
        }

        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await service.updateProfile(draft, avatar: avatar)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validate(_ draft: EditableProfile) -> String? {
        let name = draft.fullName.trimmingCharacters(in: .whitespaces)
        return FormValidator.firstError(
            name.isEmpty ? String(localized: "error_empty_fields") : nil,
            FormValidator.email(draft.email),
            FormValidator.handle(draft.handle.trimmingCharacters(in: .whitespaces)),
            canEditBirthDate && birthDate != nil ? FormValidator.birthDate(birthDate) : nil
        )
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
