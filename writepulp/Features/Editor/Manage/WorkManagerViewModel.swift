//
//  WorkManagerViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class WorkManagerViewModel {
    let workId: String
    private(set) var details: WorkDetails?
    private(set) var sections: [WorkSection] = []
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let service: EditorService

    init(workId: String, service: EditorService) {
        self.workId = workId
        self.service = service
    }

    func load() async {
        do {
            let result = try await service.workDetails(id: workId)
            details = result
            sections = result.sections.content.sorted { $0.order < $1.order }
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if details == nil { errorMessage = error.localizedDescription }
        }
    }

    func can(_ permission: WorkPermission) -> Bool { details?.can(permission) ?? false }

    var totalWords: Int { sections.reduce(0) { $0 + $1.wordCount } }

    func setStatus(_ status: WorkStatus, of section: WorkSection) async {
        guard section.status != status else { return }
        await perform {
            try await self.service.setSectionStatus(id: section.id, status)
            self.update(section.id) { $0.status = status }
        }
    }

    func toggleLock(_ section: WorkSection) async {
        await perform {
            try await self.service.toggleSectionLock(id: section.id)
            self.update(section.id) { $0.isLocked.toggle() }
        }
    }

    func delete(_ section: WorkSection) async {
        await perform {
            try await self.service.deleteSection(id: section.id)
            self.sections.removeAll { $0.id == section.id }
            self.toastMessage = String(localized: "editor_section_deleted")
        }
    }

    func togglePublish() async {
        await perform {
            try await self.service.togglePublish(workId: self.workId)
            await self.load()
        }
    }

    /// true when the work is gone and the screen should close.
    func archive() async -> Bool {
        await perform { try await self.service.archiveWork(id: self.workId) }
    }

    func deleteWork() async -> Bool {
        await perform { try await self.service.deleteWork(id: self.workId) }
    }

    @discardableResult
    private func perform(_ action: @escaping () async throws -> Void) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await action()
            return true
        } catch APIError.cancelled {
            return false
        } catch {
            toastMessage = error.localizedDescription
            return false
        }
    }

    private func update(_ id: String, _ change: (inout WorkSection) -> Void) {
        guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
        change(&sections[index])
    }
}
