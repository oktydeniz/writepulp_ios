//
//  CollectionEditorSheet.swift
//  writepulp
//

import SwiftUI

/// Create or edit a collection: name, privacy and (when editing) delete.
struct CollectionEditorSheet: View {
    enum Mode {
        case create
        case edit(UserCollection)
    }

    let mode: Mode
    let onSave: (CollectionForm) async -> String?
    var onDelete: () async -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var form: CollectionForm
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isConfirmingDelete = false

    init(mode: Mode, onSave: @escaping (CollectionForm) async -> String?, onDelete: @escaping () async -> Void = {}) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        switch mode {
        case .create:
            _form = State(initialValue: CollectionForm(name: "", isPrivate: false))
        case .edit(let collection):
            _form = State(initialValue: CollectionForm(name: collection.name, isPrivate: collection.isPrivate))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e_g_my_favorite_articles", text: $form.name)
                        .onChange(of: form.name) { errorMessage = nil }
                } header: {
                    Text("collection_name")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(AppColors.error)
                    }
                }

                Section {
                    Toggle(isOn: $form.isPrivate) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("make_private")
                                Text("private_collection_desc")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.onSurfaceVariant)
                            }
                        } icon: {
                            Image(systemName: form.isPrivate ? "lock.fill" : "globe")
                                .foregroundStyle(form.isPrivate ? AppColors.primary : AppColors.onSurface)
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("delete_collection", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .tint(AppColors.primary)
            .navigationTitle(isEditing ? "edit_collection" : "create_new_collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .alert("delete_collection", isPresented: $isConfirmingDelete) {
                Button("cancel", role: .cancel) {}
                Button("delete", role: .destructive) {
                    Task {
                        await onDelete()
                        dismiss()
                    }
                }
            } message: {
                Text("you_want_to_delete_collection")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        if let error = FormValidator.name(form.name) {
            errorMessage = error
            return
        }
        isSaving = true
        defer { isSaving = false }
        var trimmed = form
        trimmed.name = form.name.trimmingCharacters(in: .whitespaces)
        if let error = await onSave(trimmed) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
