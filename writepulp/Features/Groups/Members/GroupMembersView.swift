//
//  GroupMembersView.swift
//  writepulp
//

import SwiftUI

/// Members with role and removal actions for owners and admins, plus bulk removal.
@MainActor
struct GroupMembersView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: GroupMembersViewModel
    @State private var pendingRemoval: GroupMember?
    @State private var isConfirmingBulkRemoval = false
    @FocusState private var isSearchFocused: Bool

    init(groupId: String, viewerRole: GroupRole, service: GroupsService, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: GroupMembersViewModel(groupId: groupId, viewerRole: viewerRole, service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $model.query, isFocused: $isSearchFocused, onClear: { model.query = "" }, placeholder: "search_members")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if model.canManage && !model.isSelecting {
                Button { onOpen(.groupRequests(id: model.groupId)) } label: {
                    Label("manage_members_requests", systemImage: "person.badge.clock")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppColors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(model.isSelecting ? Text("selected_count".localized(model.selection.count)) : Text("members"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) {
            if model.isSelecting { selectionBar }
        }
        .toast($model.toastMessage)
        .loadingOverlay(model.isBusy)
        .alert(
            "are_you_sure",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { member in
            Button("cancel", role: .cancel) {}
            Button("remove_member", role: .destructive) { Task { await model.remove(member) } }
        } message: { member in
            Text(member.fullName)
        }
        .alert("are_you_sure", isPresented: $isConfirmingBulkRemoval) {
            Button("cancel", role: .cancel) {}
            Button("remove_member", role: .destructive) { Task { await model.removeSelected() } }
        } message: {
            Text("remove_selected_members".localized(model.selection.count))
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ListSkeleton(count: 8, leadingSize: 44)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if let error = model.errorMessage {
            ErrorStateView(message: error) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(model.visibleMembers) { member in
                    row(member)
                        .listRowBackground(AppColors.surface)
                        .task { await model.loadMoreIfNeeded(after: member) }
                }
                if model.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await model.load() }
        }
    }

    private func row(_ member: GroupMember) -> some View {
        let options = model.roleOptions(for: member)
        let canRemove = model.canRemove(member)
        return HStack(spacing: 12) {
            if model.isSelecting {
                Image(systemName: model.selection.contains(member.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(canRemove ? AppColors.primary : AppColors.onSurfaceVariant.opacity(0.3))
            }
            Avatar(imagePath: member.avatarImg, name: member.fullName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.isMe ? "me".localized(member.fullName) : member.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.onSurface)
                        .lineLimit(1)
                    RoleBadge(role: member.role)
                }
                Text(subtitle(member))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !model.isSelecting && (!options.isEmpty || canRemove) {
                Menu {
                    if !options.isEmpty {
                        Section("change_role") {
                            ForEach(options, id: \.self) { role in
                                Button { Task { await model.changeRole(of: member, to: role) } } label: {
                                    Text(Optional(role).titleKey)
                                }
                            }
                        }
                    }
                    if canRemove {
                        Button(role: .destructive) { pendingRemoval = member } label: {
                            Label("remove_member", systemImage: "person.badge.minus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isSelecting {
                model.toggleSelection(member)
            } else if !member.isMe {
                onOpen(.profile(userId: member.id))
            }
        }
    }

    private func subtitle(_ member: GroupMember) -> String {
        let handle = member.handle.isEmpty ? "" : "@\(member.handle)"
        guard let joined = member.joinedAt else { return handle }
        let date = "joined_date".localized(joined.formatted(date: .abbreviated, time: .omitted))
        return handle.isEmpty ? date : "\(handle) · \(date)"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.canManage && !model.removableMembers.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(model.isSelecting ? "cancel" : "select") { model.isSelecting.toggle() }
            }
        }
    }

    private var selectionBar: some View {
        HStack {
            Button("select_all_members") { model.selectAll() }
            Spacer()
            Button(role: .destructive) { isConfirmingBulkRemoval = true } label: {
                Label("remove_member", systemImage: "trash")
            }
            .disabled(model.selection.isEmpty)
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
