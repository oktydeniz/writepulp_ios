//
//  WorkSettingsView.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// The work's details: cover, title, summary, categories and publishing settings.
@MainActor
struct WorkSettingsView: View {
    let onSaved: () -> Void

    @State private var model: WorkSettingsViewModel
    @State private var isPickingCategories = false
    @State private var coverItem: PhotosPickerItem?

    init(workId: String, service: EditorService, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _model = State(initialValue: WorkSettingsViewModel(workId: workId, service: service))
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if model.publication != nil {
                form
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
                    .frame(maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("editor_work_settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.isSaving {
                    ProgressView()
                } else {
                    Button("editor_save") {
                        Task { if await model.save() { onSaved() } }
                    }
                    .disabled(!model.canSave)
                }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $isPickingCategories) {
            CategoryPickerSheet(
                groups: model.categoryGroups,
                isLoading: model.isLoadingCategories,
                selectedIds: model.categoryIds,
                limit: CreateWorkViewModel.categoryLimit,
                onToggle: { model.toggleCategory($0) }
            )
        }
        .onChange(of: coverItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.pickCover(image)
                }
                coverItem = nil
            }
        }
        .toast($model.toastMessage)
    }

    private var form: some View {
        @Bindable var model = model
        return Form {
            Section {
                coverPicker
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                TextField("editor_work_title", text: $model.title, axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .onChange(of: model.title) { _, value in
                        if value.count > CreateWorkViewModel.titleLimit {
                            model.title = String(value.prefix(CreateWorkViewModel.titleLimit))
                        }
                    }
            }

            Section {
                TextField("editor_work_summary_hint", text: $model.summary, axis: .vertical)
                    .lineLimit(4...10)
                    .onChange(of: model.summary) { _, value in
                        if value.count > CreateWorkViewModel.summaryLimit {
                            model.summary = String(value.prefix(CreateWorkViewModel.summaryLimit))
                        }
                    }
            } header: {
                Text("editor_work_summary")
            } footer: {
                Text(verbatim: "\(model.summary.count)/\(CreateWorkViewModel.summaryLimit)")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Section {
                Button { isPickingCategories = true } label: {
                    HStack {
                        Text("editor_work_categories").foregroundStyle(AppColors.onSurface)
                        Spacer()
                        Text(model.categoryIds.isEmpty
                             ? String(localized: "editor_select")
                             : model.selectedCategoryNames.joined(separator: ", "))
                            .lineLimit(1)
                            .foregroundStyle(AppColors.onSurfaceVariant)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                }
                TextField("editor_work_tags_hint", text: $model.tags)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("editor_work_discovery")
            } footer: {
                Text("editor_work_categories_footer \(CreateWorkViewModel.categoryLimit)")
            }

            Section("editor_work_settings") {
                Picker("editor_work_language", selection: $model.language) {
                    ForEach(model.languages, id: \.self) { code in
                        Text(ContentLanguage.displayName(for: code)).tag(code)
                    }
                }
                Picker("editor_work_age", selection: $model.ageCategory) {
                    ForEach(AgeCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("editor_work_copyright", selection: $model.copyright) {
                    ForEach(WorkCopyright.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("editor_work_free", isOn: $model.isFree)
                Toggle("editor_work_ai", isOn: $model.isSupportedWithAI)
                Toggle("editor_work_completed", isOn: $model.isCompleted)
            }
            .tint(AppColors.primary)

            if model.offersCommunity {
                Section {
                    Toggle("editor_work_create_community", isOn: $model.createCommunity)
                    if model.createCommunity {
                        Toggle("editor_work_community_approval", isOn: $model.requireApproval)
                    }
                }
                .tint(AppColors.primary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var coverPicker: some View {
        // The picker's label closure is not main-actor isolated.
        let newCover = model.newCover
        let path = model.coverPath
        return HStack(spacing: 16) {
            PhotosPicker(selection: $coverItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(AppColors.background)
                    if newCover != nil || path != nil {
                        ComposerCoverImage(local: newCover, path: path)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .frame(width: 84, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(AppColors.outline) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("editor_work_cover")
                    .font(.system(size: 16, weight: .bold))
                Text("editor_work_cover_hint")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                if model.hasCover {
                    Button("editor_remove", role: .destructive) { model.removeCover() }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}
