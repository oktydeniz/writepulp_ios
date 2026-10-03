//
//  GroupMembersViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class GroupMembersViewModel {
    let groupId: String
    /// The viewer's role in the group.
    let viewerRole: GroupRole
    private(set) var members = PagedList<GroupMember>()
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    var query = ""
    var isSelecting = false {
        didSet { if !isSelecting { selection = [] } }
    }
    var selection: Set<String> = []
    var toastMessage: String?

    private let service: GroupsService

    init(groupId: String, viewerRole: GroupRole, service: GroupsService) {
        self.groupId = groupId
        self.viewerRole = viewerRole
        self.service = service
    }

    var canManage: Bool { viewerRole.canManage }

    /// Filters what's loaded; the server has no member search.
    var visibleMembers: [GroupMember] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return members.items }
        return members.items.filter {
            $0.fullName.localizedCaseInsensitiveContains(trimmed) || $0.handle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var removableMembers: [GroupMember] { members.items.filter(canRemove) }

    // MARK: - Permissions (mirrors the server's rules)

    /// Owners remove anyone but themselves; admins remove members and moderators.
    func canRemove(_ member: GroupMember) -> Bool {
        guard !member.isMe, member.role != .owner else { return false }
        switch viewerRole {
        case .owner: return true
        case .admin: return member.role == .member || member.role == .moderator
        default: return false
        }
    }

    /// Same matrix as web and Android: owners promote and demote, admins only make members moderators.
    func roleOptions(for member: GroupMember) -> [GroupRole] {
        guard !member.isMe else { return [] }
        switch (viewerRole, member.role) {
        case (.owner, .member): return [.moderator, .admin]
        case (.owner, .moderator): return [.admin, .member]
        case (.owner, .admin): return [.member]
        case (.admin, .member): return [.moderator]
        default: return []
        }
    }

    // MARK: - Loading

    func load() async {
        isLoading = !members.hasLoaded
        defer { isLoading = false }
        do {
            members.apply(try await service.members(id: groupId, page: 0), replacing: true)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if members.hasLoaded { toastMessage = error.localizedDescription } else { errorMessage = error.localizedDescription }
        }
    }

    func loadMoreIfNeeded(after member: GroupMember) async {
        guard member.id == members.items.last?.id, members.hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let page = try? await service.members(id: groupId, page: members.nextPage) {
            members.apply(page, replacing: false)
        }
    }

    // MARK: - Actions

    func toggleSelection(_ member: GroupMember) {
        guard canRemove(member) else { return }
        if selection.contains(member.id) { selection.remove(member.id) } else { selection.insert(member.id) }
    }

    func selectAll() {
        selection = Set(removableMembers.map(\.id))
    }

    func remove(_ member: GroupMember) async {
        await perform {
            try await self.service.kick(id: self.groupId, userId: member.id)
            self.members.removeAll { $0.id == member.id }
        }
    }

    func removeSelected() async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        await perform {
            try await self.service.bulkRemove(id: self.groupId, userIds: ids)
            self.members.removeAll { ids.contains($0.id) }
            self.isSelecting = false
        }
    }

    func changeRole(of member: GroupMember, to role: GroupRole) async {
        await perform {
            try await self.service.updateRole(id: self.groupId, userId: member.id, role: role)
            self.members.update(where: { $0.id == member.id }) { $0.role = role }
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}
