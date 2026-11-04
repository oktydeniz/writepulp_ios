//
//  WorkTeamView.swift
//  writepulp
//

import SwiftUI

/// The people working on a work. Everyone on the team sees them; the owner also invites people,
/// changes roles and removes members.
@MainActor
struct WorkTeamView: View {
    @State private var model: WorkTeamViewModel
    @State private var isInviting = false
    @State private var pendingRemoval: WorkCollaborator?

    init(workId: String, service: EditorService) {
        _model = State(initialValue: WorkTeamViewModel(workId: workId, service: service))
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isLoaded {
                content
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
                    .frame(maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("editor_team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isInviting = true } label: { Image(systemName: "person.badge.plus") }
                        .accessibilityLabel(Text("editor_team_invite"))
                }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .loadingOverlay(model.isWorking)
        .toast($model.toastMessage)
        .sheet(isPresented: $isInviting) {
            InviteCollaboratorSheet { handle, role in
                await model.invite(handle: handle, role: role)
            }
        }
        .alert("editor_team_remove_title", isPresented: removalBinding, presenting: pendingRemoval) { member in
            Button("cancel", role: .cancel) {}
            Button("editor_remove", role: .destructive) { Task { await model.remove(member) } }
        } message: { member in
            Text("editor_team_remove_message \(member.fullName)")
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
    }

    private var content: some View {
        List {
            Section {
                if model.members.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "editor_team_empty_title",
                        message: model.isOwner ? "editor_team_empty_message" : "editor_team_empty_member_message"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(model.members) { row($0) }
                }
            } footer: {
                if model.isOwner { Text("editor_team_footer") }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ member: WorkCollaborator) -> some View {
        HStack(spacing: 12) {
            Avatar(imagePath: member.avatarImg, name: member.fullName)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(1)
                Text(verbatim: "@\(member.handle)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.isOwner {
                Menu {
                    Picker(selection: Binding(
                        get: { member.role },
                        set: { role in Task { await model.setRole(role, of: member) } }
                    )) {
                        ForEach(CollaboratorRole.assignable, id: \.self) { Text($0.label).tag($0) }
                    } label: {
                        Label("editor_team_role", systemImage: "person.text.rectangle")
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Button(role: .destructive) { pendingRemoval = member } label: {
                        Label("editor_remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    roleLabel(member.role, showsChevron: true)
                }
            } else {
                roleLabel(member.role, showsChevron: false)
            }
        }
    }

    private func roleLabel(_ role: CollaboratorRole, showsChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(role.label)
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppColors.primary)
    }
}

/// Invites someone by handle; they join once they accept the notification.
private struct InviteCollaboratorSheet: View {
    /// true once the invitation went out and the sheet can close.
    let onInvite: (_ handle: String, _ role: CollaboratorRole) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""
    @State private var role = CollaboratorRole.translator
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("editor_team_handle", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("editor_team_role", selection: $role) {
                        ForEach(CollaboratorRole.assignable, id: \.self) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text(role.hint)
                }
            }
            .navigationTitle("editor_team_invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("editor_team_send") {
                            Task {
                                isSending = true
                                let sent = await onInvite(handle, role)
                                isSending = false
                                if sent { dismiss() }
                            }
                        }
                        .disabled(handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension CollaboratorRole {
    var label: LocalizedStringKey {
        switch self {
        case .coAuthor: "editor_role_co_author"
        case .editor: "editor_role_editor"
        case .translator: "editor_role_translator"
        case .contributor: "editor_role_contributor"
        case .viewerAuthor: "editor_role_viewer"
        }
    }

    /// What the role may do, matching its backend permissions.
    var hint: LocalizedStringKey {
        switch self {
        case .coAuthor: "editor_role_co_author_hint"
        case .editor: "editor_role_editor_hint"
        case .translator: "editor_role_translator_hint"
        case .contributor: "editor_role_contributor_hint"
        case .viewerAuthor: "editor_role_viewer_hint"
        }
    }
}
