//
//  ProfileService.swift
//  writepulp
//

import UIKit

@MainActor
final class ProfileService {
    enum AvatarChange {
        case keep
        case replace(UIImage)
        case remove

        var isRemoval: Bool {
            if case .remove = self { return true }
            return false
        }
    }

    private let api: APIClient
    private let session: SessionStore

    nonisolated init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    var currentUserId: String? { session.userId }

    /// nil means the signed-in user.
    func profile(userId: String?) async throws -> UserProfile {
        try await api.send(ProfileAPI.profile(userId: userId))
    }

    func publications(userId: String?, page: Int) async throws -> Page<PublicationSummary> {
        try await api.send(ProfileAPI.publications(userId: userId, page: page))
    }

    func toggleFollow(userId: String) async throws {
        _ = try await api.send(ProfileAPI.toggleFollow(userId: userId))
    }

    func respondToFollowRequest(userId: String, approve: Bool) async throws {
        _ = try await api.send(ProfileAPI.respondToFollowRequest(userId: userId, approve: approve))
    }

    func follows(userId: String?, kind: FollowListKind, page: Int) async throws -> Page<FollowUser> {
        try await api.send(ProfileAPI.follows(userId: userId, kind: kind, page: page))
    }

    // MARK: - Edit

    func editableProfile() async throws -> EditableProfile {
        try await api.send(ProfileAPI.editableProfile())
    }

    /// Uploads a new avatar first when there is one, then saves the profile and the cached user info.
    func updateProfile(_ draft: EditableProfile, avatar: AvatarChange) async throws -> ProfileUpdateResult {
        var avatarPath = draft.avatarImg
        switch avatar {
        case .keep:
            break
        case .remove:
            avatarPath = nil
        case .replace(let image):
            guard let jpeg = image.compressedJPEG() else {
                throw ProfileError.imageProcessing
            }
            let uploaded = try await api.send(ImageUploadAPI.upload(jpeg: jpeg, type: .avatar))
            avatarPath = uploaded["filePath"]
        }

        let request = ProfileUpdateRequest(
            fullName: draft.fullName.trimmingCharacters(in: .whitespaces),
            birthDate: draft.birthDate,
            avatarImg: avatarPath,
            location: draft.location,
            about: draft.about,
            handle: draft.handle.trimmingCharacters(in: .whitespaces),
            email: draft.email.trimmingCharacters(in: .whitespaces),
            socialLinks: draft.socialLinks ?? SocialLinks(),
            isAvatarRemoved: avatar.isRemoval
        )
        let result = try await api.send(ProfileAPI.update(request))
        session.updateUserInfo(fullName: request.fullName, handle: request.handle, email: request.email, avatar: avatarPath)
        return result
    }
}

enum ProfileError: LocalizedError {
    case imageProcessing

    var errorDescription: String? {
        String(localized: "the_image_could_not_be_processed")
    }
}
