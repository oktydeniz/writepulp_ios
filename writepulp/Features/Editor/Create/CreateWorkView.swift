//
//  CreateWorkView.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// New work form: cover, title, summary, categories and publishing settings.
/// The work is created as a draft; chapters are added from its manager.
@MainActor
struct CreateWorkView: View {
    let onCreated: (String) -> Void

    @State private var model: CreateWorkViewModel
    @State private var isPickingCategories = false
    @State private var coverItem: PhotosPickerItem?
    @State private var isConfirmingOriginality = false

    init(type: PublicationType, service: EditorService, onCreated: @escaping (String) -> Void) {
        self.onCreated = onCreated
        _model = State(initialValue: CreateWorkViewModel(type: type, service: service))
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                coverPicker
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                Picker("editor_work_type", selection: $model.type) {
                    ForEach(PublicationType.writable, id: \.self) { Text($0.label).tag($0) }
                }
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
                    ForEach(ContentLanguage.codes, id: \.self) { code in
                        Text(ContentLanguage.displayName(for: code)).tag(code)
                    }
                }
                Picker("editor_work_age", selection: $model.ageCategory) {
                    ForEach(AgeCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                CopyrightPicker(selection: $model.copyright)
                Toggle("editor_work_free", isOn: $model.isFree)
                Toggle("editor_work_ai", isOn: $model.isSupportedWithAI)
            }
            .tint(AppColors.primary)

            Section {
                PrimaryButton(title: "editor_create_work", isLoading: model.isSaving) {
                    isConfirmingOriginality = true
                }
                .disabled(!model.canSubmit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(model.type.isSingleSection ? "editor_create_single_footer" : "editor_create_work_footer")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("editor_new_work")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadCategories() }
        .sheet(isPresented: $isPickingCategories) {
            CategoryPickerSheet(
                groups: model.categoryGroups,
                isLoading: model.isLoadingCategories,
                selectedIds: model.categoryIds,
                limit: CreateWorkViewModel.categoryLimit,
                onToggle: { model.toggleCategory($0) }
            )
        }
        .sheet(isPresented: $isConfirmingOriginality) {
            OriginalitySheet(onCancel: { isConfirmingOriginality = false }) {
                isConfirmingOriginality = false
                Task {
                    if let id = await model.submit() { onCreated(id) }
                }
            }
        }
        .onChange(of: coverItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.cover = image
                }
                coverItem = nil
            }
        }
        .toast($model.toastMessage)
    }

    private var coverPicker: some View {
        // The picker's label closure is not main-actor isolated.
        let cover = model.cover
        return HStack(spacing: 16) {
            PhotosPicker(selection: $coverItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(AppColors.background)
                    if let cover {
                        Image(uiImage: cover).resizable().scaledToFill()
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
                if model.cover != nil {
                    Button("editor_remove", role: .destructive) { model.cover = nil }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

extension AgeCategory {
    var label: LocalizedStringKey {
        switch self {
        case .allAges: "editor_age_all"
        case .child: "editor_age_child"
        case .teenager: "editor_age_teen"
        case .adult: "editor_age_adult"
        }
    }
}

extension WorkCopyright {
    /// The reader's copyright labels.
    var label: LocalizedStringKey {
        switch self {
        case .allRightsReserved: "copyright_all_rights_reserved_label"
        case .publicDomain: "copyright_public_domain_label"
        case .ccBy: "copyright_cc_by_label"
        case .ccByNc: "copyright_cc_by_nc_label"
        case .ccByNcNd: "copyright_cc_by_nc_nd_label"
        case .ccBySa: "copyright_cc_by_sa_label"
        case .ccByNd: "copyright_cc_by_nd_label"
        case .ccByNcSa: "copyright_cc_by_nc_sa_label"
        }
    }

    /// What others may do with the work under this licence.
    var summary: LocalizedStringKey {
        switch self {
        case .allRightsReserved: "copyright_all_rights_reserved_description"
        case .publicDomain: "copyright_public_domain_description"
        case .ccBy: "copyright_cc_by_description"
        case .ccByNc: "copyright_cc_by_nc_description"
        case .ccByNcNd: "copyright_cc_by_nc_nd_description"
        case .ccBySa: "copyright_cc_by_sa_description"
        case .ccByNd: "copyright_cc_by_nd_description"
        case .ccByNcSa: "copyright_cc_by_nc_sa_description"
        }
    }
}

/// The licence picker: every option in the menu carries its explanation (a native `Picker`
/// menu drops subtitles), and the chosen one is spelled out under the row.
struct CopyrightPicker: View {
    @Binding var selection: WorkCopyright

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                ForEach(WorkCopyright.allCases, id: \.self) { option in
                    // Flat label children: the menu shows the second text as a subtitle.
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Image(systemName: "checkmark")
                        }
                        Text(option.label)
                        Text(option.summary)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("editor_work_copyright")
                        .foregroundStyle(AppColors.onSurface)
                    Spacer(minLength: 12)
                    Text(selection.label)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AppColors.primary)
                .contentShape(Rectangle())
            }
            Text(selection.summary)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.onSurface.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Asked once per work, before it is created: the writer confirms the content is theirs to share.
struct OriginalitySheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isChecked = false
    @State private var contentHeight: CGFloat = 560

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 60, height: 60)
                    .background(AppColors.primary.opacity(0.12), in: Circle())
                    .padding(.top, 8)
                Text("originality_title")
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("originality_message")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button { isChecked.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(isChecked ? AppColors.primary : AppColors.onSurface.opacity(0.4))
                        Text("originality_check")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.onSurface)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(AppColors.onSurface.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChecked ? .isSelected : [])
                PrimaryButton(title: "originality_confirm", action: onConfirm)
                    .disabled(!isChecked)
                Button("cancel", action: onCancel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.onSurface.opacity(0.7))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // Fits the whole message and both buttons; scrolls only on very small screens.
        .presentationDetents([.height(contentHeight + 16)])
        .presentationDragIndicator(.visible)
    }
}
