//
//  WorkManagerViewModel.swift
//  writepulp
//

import Observation
import SwiftUI

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
            var result = try await service.workDetails(id: workId)
            // Totals, numbering and reordering all need every chapter.
            if !result.sections.last, let total = result.sections.totalElements {
                result = try await service.workDetails(id: workId, size: total)
            }
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
            // The backend renumbered the rest.
            await self.load()
        }
    }

    /// Chapters swap the numbers they already hold, so chapters beyond the loaded page aren't touched.
    func moveSections(from source: IndexSet, to destination: Int) async {
        let previous = sections
        let numbers = previous.map(\.order).sorted()
        var moved = previous
        moved.move(fromOffsets: source, toOffset: destination)
        for index in moved.indices { moved[index].order = numbers[index] }
        sections = moved

        let oldOrders = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0.order) })
        let changes = moved
            .filter { $0.order != oldOrders[$0.id] }
            .map { SectionOrderRequest(sectionId: $0.id, newOrder: $0.order) }
        do {
            try await service.reorderSections(workId: workId, changes)
        } catch APIError.cancelled {
            sections = previous
        } catch {
            sections = previous
            toastMessage = error.localizedDescription
        }
    }

    func togglePublish() async {
        await perform {
            try await self.service.togglePublish(workId: self.workId)
            await self.load()
        }
    }

    /// Returns the translation's id.
    func createTranslation(title: String, language: String) async -> String? {
        var id: String?
        await perform {
            let request = TranslationCreateRequest(title: title, language: language)
            id = try await self.service.createTranslation(workId: self.workId, request)
        }
        return id
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
