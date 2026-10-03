//
//  GroupEditorView.swift
//  writepulp
//

import PhotosUI
import SwiftUI

@MainActor
struct GroupEditorView: View {
    /// Called with the community's id and name after a successful save.
    let onSaved: (String, String) -> Void

    @State private var model: GroupEditorViewModel
    @State private var photoItem: PhotosPickerItem?

    init(groupId: String?, service: GroupsService, onSaved: @escaping (String, String) -> Void) {
        self.onSaved = onSaved
        _model = State(initialValue: GroupEditorViewModel(groupId: groupId, service: service))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
            } else {
                form
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(model.isEditing ? "edit_community" : "create_community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(model.isEditing ? "save" : "create") {
                    Task {
                        if let id = await model.save() { onSaved(id, model.name) }
                    }
                }
                .disabled(model.isSaving || model.isLoading)
            }
        }
        .toast($model.toastMessage)
        .loadingOverlay(model.isSaving)
        .sheet(isPresented: $model.isPickingCategories) {
            CategoryPickerSheet(
                groups: model.categoryGroups,
                isLoading: model.isLoadingCategories,
                selectedIds: model.categoryIds,
                limit: GroupEditorViewModel.maxCategories,
                onToggle: { model.toggleCategory($0) }
            )
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.newAvatar = image
                }
                photoItem = nil
            }
        }
        .task { await model.load() }
    }

    private var form: some View {
        Form {
            Section {
                avatarPicker
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section("community_name") {
                TextField("community_name_placeholder", text: $model.name)
                    .textInputAutocapitalization(.words)
            }

            Section("description") {
                TextField("tell_us_about_community", text: $model.description, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Toggle(isOn: $model.isPrivate) {
                    toggleLabel("private_community", detail: "private_community_desc")
                }
                Toggle(isOn: $model.restrictedMessaging) {
                    toggleLabel("restricted_messaging", detail: "restricted_messaging_desc")
                }
            }
            .tint(AppColors.primary)

            Section("categories") {
                Button { Task { await model.openCategoryPicker() } } label: {
                    HStack {
                        Group {
                            if model.selectedCategoryNames.isEmpty {
                                Text("select_category").foregroundStyle(AppColors.onSurfaceVariant)
                            } else {
                                Text(model.selectedCategoryNames.joined(separator: ", ")).foregroundStyle(AppColors.onSurface)
                            }
                        }
                        .lineLimit(2)
                        Spacer()
                        Text("\(model.categoryIds.count)/\(GroupEditorViewModel.maxCategories)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                }
            }

            Section {
                TextField("tags_hint", text: $model.tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("tags")
            }

            Section {
                ForEach(Array(model.rules.enumerated()), id: \.offset) { index, rule in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                        Text(rule)
                    }
                }
                .onDelete { model.rules.remove(atOffsets: $0) }
                .onMove { model.rules.move(fromOffsets: $0, toOffset: $1) }

                HStack {
                    TextField("add_rule_hint", text: $model.newRule, axis: .vertical)
                        .onSubmit { model.addRule() }
                    Button { model.addRule() } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22))
                    }
                    .foregroundStyle(AppColors.primary)
                    .disabled(model.newRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("add_new_rule"))
                }
            } header: {
                Text("community_rules")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var avatarPicker: some View {
        VStack(spacing: 10) {
            Group {
                if let image = model.newAvatar {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    GroupAvatar(imagePath: model.hasAvatar ? model.remoteAvatar : nil, size: 96)
                }
            }
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(model.hasAvatar ? "change_avatar" : "add_avatar")
                        .font(.system(size: 14, weight: .semibold))
                }
                if model.hasAvatar {
                    Button("remove_avatar", role: .destructive) { model.removeAvatar() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func toggleLabel(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
    }
}
