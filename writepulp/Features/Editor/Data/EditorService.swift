//
//  EditorService.swift
//  writepulp
//

import Foundation

/// Writer endpoints: works, their sections and the section body.
enum EditorAPI {
    static func dashboard(page: Int) -> Endpoint<WriterDashboard> {
        Endpoint(
            path: "dashboard/publications",
            query: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "20")]
        )
    }

    static func workDetails(id: String, size: Int) -> Endpoint<WorkDetails> {
        Endpoint(
            path: "dashboard/publications/\(id)/details",
            query: [
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "size", value: "\(size)"),
                URLQueryItem(name: "sort", value: "order,asc"),
            ]
        )
    }

    static func createWork(_ request: WorkCreateRequest) -> Endpoint<SavedContent> {
        Endpoint(path: "publications", method: .post, body: request)
    }

    static func togglePublish(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(id)/toggle-publish", method: .patch)
    }

    static func archiveWork(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(id)/archive", method: .patch)
    }

    static func deleteWork(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(id)", method: .delete)
    }

    static func updateWork(id: String, _ request: WorkUpdateRequest) -> Endpoint<SavedContent> {
        Endpoint(path: "publications/\(id)", method: .put, body: request)
    }

    static func createTranslation(workId: String, _ request: TranslationCreateRequest) -> Endpoint<SavedContent> {
        Endpoint(path: "publications/\(workId)/translations", method: .post, body: request)
    }

    static func inviteCollaborator(workId: String, _ request: CollaboratorInviteRequest) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(workId)/collaborators/invite", method: .post, body: request)
    }

    static func setCollaboratorRole(workId: String, userId: String, _ role: CollaboratorRole) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "publications/\(workId)/collaborators/\(userId)/role",
            method: .patch,
            query: [URLQueryItem(name: "newRole", value: role.rawValue)]
        )
    }

    static func removeCollaborator(workId: String, userId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "publications/\(workId)/collaborators/\(userId)", method: .delete)
    }

    static func section(id: String) -> Endpoint<SectionDraftResponse> {
        Endpoint(path: "sections/writer-detail/\(id)")
    }

    /// Answers without the envelope.
    static func createSection(workId: String, _ request: SectionSaveRequest) -> Endpoint<SavedContent> {
        Endpoint(path: "sections/\(workId)", method: .post, body: request, isEnveloped: false)
    }

    /// Answers without the envelope; 409 when `contentRevision` is stale.
    static func updateSection(id: String, _ request: SectionSaveRequest) -> Endpoint<SavedContent> {
        Endpoint(path: "sections/\(id)", method: .put, body: request, isEnveloped: false)
    }

    static func setSectionStatus(id: String, _ status: WorkStatus) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/\(id)/status/\(status.rawValue)", method: .patch)
    }

    static func toggleSectionLock(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/\(id)/toggle-lock", method: .patch)
    }

    static func deleteSection(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/\(id)", method: .delete)
    }

    static func reorderSections(workId: String, _ orders: [SectionOrderRequest]) -> Endpoint<EmptyResponse> {
        Endpoint(path: "sections/reorder/\(workId)", method: .patch, body: orders)
    }
}

@MainActor
final class EditorService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    func dashboard(page: Int) async throws -> WriterDashboard {
        try await api.send(EditorAPI.dashboard(page: page))
    }

    func workDetails(id: String, size: Int = 50) async throws -> WorkDetails {
        try await api.send(EditorAPI.workDetails(id: id, size: size))
    }

    func categories() async throws -> [CategoryGroup] {
        try await api.send(CategoryAPI.grouped())
    }

    /// Returns the new work's id.
    func createWork(_ request: WorkCreateRequest) async throws -> String {
        try await api.send(EditorAPI.createWork(request)).id
    }

    func togglePublish(workId: String) async throws {
        _ = try await api.send(EditorAPI.togglePublish(id: workId))
    }

    func archiveWork(id: String) async throws {
        _ = try await api.send(EditorAPI.archiveWork(id: id))
    }

    func deleteWork(id: String) async throws {
        _ = try await api.send(EditorAPI.deleteWork(id: id))
    }

    func updateWork(id: String, _ request: WorkUpdateRequest) async throws {
        _ = try await api.send(EditorAPI.updateWork(id: id, request))
    }

    /// Returns the translation's id.
    func createTranslation(workId: String, _ request: TranslationCreateRequest) async throws -> String {
        try await api.send(EditorAPI.createTranslation(workId: workId, request)).id
    }

    func inviteCollaborator(workId: String, handle: String, role: CollaboratorRole) async throws {
        let request = CollaboratorInviteRequest(targetUserHandle: handle, role: role)
        _ = try await api.send(EditorAPI.inviteCollaborator(workId: workId, request))
    }

    func setCollaboratorRole(workId: String, userId: String, _ role: CollaboratorRole) async throws {
        _ = try await api.send(EditorAPI.setCollaboratorRole(workId: workId, userId: userId, role))
    }

    func removeCollaborator(workId: String, userId: String) async throws {
        _ = try await api.send(EditorAPI.removeCollaborator(workId: workId, userId: userId))
    }

    func section(id: String) async throws -> SectionDraft {
        try await api.send(EditorAPI.section(id: id)).section
    }

    func createSection(workId: String, _ request: SectionSaveRequest) async throws -> SavedContent {
        try await api.send(EditorAPI.createSection(workId: workId, request))
    }

    func updateSection(id: String, _ request: SectionSaveRequest) async throws -> SavedContent {
        try await api.send(EditorAPI.updateSection(id: id, request))
    }

    func setSectionStatus(id: String, _ status: WorkStatus) async throws {
        _ = try await api.send(EditorAPI.setSectionStatus(id: id, status))
    }

    func toggleSectionLock(id: String) async throws {
        _ = try await api.send(EditorAPI.toggleSectionLock(id: id))
    }

    func deleteSection(id: String) async throws {
        _ = try await api.send(EditorAPI.deleteSection(id: id))
    }

    func reorderSections(workId: String, _ orders: [SectionOrderRequest]) async throws {
        _ = try await api.send(EditorAPI.reorderSections(workId: workId, orders))
    }

    /// Uploads an image and returns its server path: `.section` for section covers and blocks,
    /// `.cover` for a work's cover.
    func uploadImage(_ jpeg: Data, type: ImageUploadType = .section) async throws -> String {
        let result = try await api.send(ImageUploadAPI.upload(jpeg: jpeg, type: type))
        guard let path = result["filePath"] else { throw APIError.invalidResponse }
        return path
    }
}
