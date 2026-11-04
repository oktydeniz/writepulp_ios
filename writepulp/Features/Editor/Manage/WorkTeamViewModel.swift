//
//  WorkTeamViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class WorkTeamViewModel {
    private(set) var members: [WorkCollaborator] = []
    private(set) var isOwner = false
    private(set) var isLoaded = false
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    var toastMessage: String?

    private let workId: String
    private let service: EditorService

    init(workId: String, service: EditorService) {
        self.workId = workId
        self.service = service
    }

    func load() async {
        do {
            let details = try await service.workDetails(id: workId)
            members = details.collaborators
            isOwner = details.isOwner
            isLoaded = true
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if !isLoaded { errorMessage = error.localizedDescription }
        }
    }

    /// true when the invitation went out and the sheet can close.
    func invite(handle: String, role: CollaboratorRole) async -> Bool {
        // People copy handles with their "@".
        let cleanHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !cleanHandle.isEmpty else { return false }
        return await perform {
            try await self.service.inviteCollaborator(workId: self.workId, handle: cleanHandle, role: role)
            self.toastMessage = "editor_team_invite_sent".localized(cleanHandle)
        }
    }

    func setRole(_ role: CollaboratorRole, of member: WorkCollaborator) async {
        guard member.role != role else { return }
        await perform {
            try await self.service.setCollaboratorRole(workId: self.workId, userId: member.id, role)
            await self.load()
        }
    }

    func remove(_ member: WorkCollaborator) async {
        await perform {
            try await self.service.removeCollaborator(workId: self.workId, userId: member.id)
            self.members.removeAll { $0.id == member.id }
        }
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
}
