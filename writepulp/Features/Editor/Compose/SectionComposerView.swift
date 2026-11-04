//
//  SectionComposerView.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// Writes one section: title, blocks edited in place, block / section settings and a reader preview.
@MainActor
struct SectionComposerView: View {
    let onClose: () -> Void

    @State private var model: SectionComposerViewModel
    @State private var insertAfterId: String?
    @State private var isPickingBlock = false
    @State private var inspectedId: String?
    @State private var isShowingSettings = false
    @State private var isShowingPreview = false
    @State private var isConfirmingLeave = false
    @State private var pendingDeleteId: String?
    @State private var coverItem: PhotosPickerItem?
    @FocusState private var isTitleFocused: Bool

    init(workId: String, sectionId: String?, service: EditorService, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _model = State(initialValue: SectionComposerViewModel(workId: workId, sectionId: sectionId, service: service))
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.loadError {
                ErrorStateView(message: error) { Task { await model.load() } }
                    .frame(maxHeight: .infinity)
            } else {
                canvas
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbar }
        .task { await model.load() }
        .toast($model.toastMessage)
        .sheet(isPresented: $isPickingBlock) {
            BlockPickerSheet { kind in model.insert(kind, after: insertAfterId) }
        }
        .sheet(item: inspectedBinding) { item in
            BlockInspectorSheet(block: blockBinding(item.id)) { image in
                Task { await model.uploadImage(image, for: item.id) }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SectionSettingsSheet(model: model)
        }
        .sheet(isPresented: $isShowingPreview) {
            ComposerPreviewSheet(
                title: model.title,
                hero: model.isMagazine ? model.draft : nil,
                localCover: model.localCover,
                document: model.documentForSave(),
                themeId: model.themeId,
                fontId: model.fontId,
                fontSize: model.fontSize
            )
        }
        .confirmationDialog("editor_leave_title", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("editor_save_and_exit") {
                Task { if await model.save() { onClose() } }
            }
            Button("editor_leave_discard", role: .destructive, action: onClose)
            Button("cancel", role: .cancel) {}
        } message: {
            Text("editor_leave_message")
        }
        .alert("editor_delete_block", isPresented: Binding(
            get: { pendingDeleteId != nil },
            set: { if !$0 { pendingDeleteId = nil } }
        )) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                if let id = pendingDeleteId { withAnimation { model.delete(id) } }
            }
        } message: {
            Text("editor_delete_block_message")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if model.isDirty { isConfirmingLeave = true } else { onClose() }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
            }
            .accessibilityLabel(Text("back"))
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(model.isSingleSection
                     ? (model.isNew ? "editor_create_content" : "editor_edit_content")
                     : (model.isNew ? "editor_new_section" : "editor_edit_section"))
                    .font(.system(size: 15, weight: .semibold))
                saveStatus
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button { isShowingPreview = true } label: { Label("editor_preview", systemImage: "eye") }
                Button { isShowingSettings = true } label: { Label("editor_section_settings", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            Button {
                Task { await model.save() }
            } label: {
                if model.isSaving {
                    ProgressView()
                } else {
                    Text("editor_save").fontWeight(.bold)
                }
            }
            .disabled(model.isSaving || model.isLoading || model.loadError != nil)
        }
    }

    @ViewBuilder
    private var saveStatus: some View {
        if model.isSaving {
            Text("editor_saving")
        } else if model.isUploading {
            Text("editor_uploading")
        } else if model.isDirty {
            Text("editor_unsaved")
        } else if let date = model.lastSavedAt {
            Text("editor_saved_at \(date.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("editor_words_minutes \(model.wordCount) \(model.readingMinutes)")
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    titleField
                        .padding(.bottom, 8)

                    if model.isMagazine {
                        magazineHero
                            .padding(.bottom, 8)
                    }

                    if model.document.blocks.isEmpty {
                        Text("editor_empty_doc")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    ForEach(model.document.blocks) { block in
                        VStack(alignment: .leading, spacing: 4) {
                            if model.selectedId == block.id {
                                blockBar(block)
                                    .transition(.opacity)
                            }
                            BlockEditorRow(
                                block: blockBinding(block.id),
                                isSelected: model.selectedId == block.id,
                                isUploading: model.uploadingIds.contains(block.id),
                                onSelect: { select(block.id) },
                                onSettings: { inspectedId = block.id },
                                onPickImage: { image in Task { await model.uploadImage(image, for: block.id) } }
                            )
                            if model.selectedId == block.id {
                                insertButton(after: block.id)
                            }
                        }
                        .id(block.id)
                    }

                    addBlockButton
                        .padding(.top, 12)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 20)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.selectedId) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// The magazine page's hero on the canvas: tap for its settings, or change the cover from here.
    private var magazineHero: some View {
        // The picker's label closure is not main-actor isolated.
        let hasCover = model.draft.coverImg != nil
        return MagazineHeroCard(title: model.title, draft: model.draft, localCover: model.localCover)
            .overlay {
                if model.uploadingIds.contains("cover") {
                    RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35))
                    ProgressView().tint(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isShowingSettings = true }
            .overlay(alignment: .topTrailing) {
                PhotosPicker(selection: $coverItem, matching: .images) {
                    Label(hasCover ? "editor_replace_image" : "editor_pick_image", systemImage: "photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .disabled(model.uploadingIds.contains("cover"))
                .padding(10)
            }
            .onChange(of: coverItem) { _, item in
                guard let item else { return }
                Task {
                    await model.uploadCover(from: item)
                    coverItem = nil
                }
            }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let workTitle = model.workTitle {
                Text(workTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 10)
            }
            TextField(model.isSingleSection ? "editor_content_title_hint" : "editor_section_title_hint", text: $model.title, axis: .vertical)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .focused($isTitleFocused)
                .submitLabel(.next)
                .onChange(of: model.title) { _, value in
                    let clean = value.replacingOccurrences(of: "\n", with: " ")
                    let limited = String(clean.prefix(SectionComposerViewModel.titleLimit))
                    if limited != value { model.title = limited }
                }
                .onSubmit { isTitleFocused = false }
                .padding(.horizontal, 10)
            HStack {
                if model.title.trimmingCharacters(in: .whitespaces).isEmpty, !model.isNew || model.isDirty {
                    Text(model.isSingleSection ? "editor_content_title_required" : "editor_title_required").foregroundStyle(AppColors.error.opacity(0.8))
                }
                Spacer()
                Text(verbatim: "\(model.title.count)/\(SectionComposerViewModel.titleLimit)")
            }
            .font(.system(size: 11))
            .foregroundStyle(AppColors.onSurfaceVariant)
            .padding(.horizontal, 10)
            Divider().padding(.top, 4)
        }
    }

    private func blockBar(_ block: EditableBlock) -> some View {
        let index = model.index(of: block.id) ?? 0
        return HStack(spacing: 2) {
            Label {
                Text(block.kind?.title ?? LocalizedStringKey(block.type))
            } icon: {
                Image(systemName: block.kind?.systemImage ?? "puzzlepiece.extension")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.primary)
            .padding(.leading, 8)
            Spacer()
            barButton("arrow.up", label: "editor_move_up", disabled: index == 0) {
                withAnimation { model.move(block.id, by: -1) }
            }
            barButton("arrow.down", label: "editor_move_down", disabled: index >= model.document.blocks.count - 1) {
                withAnimation { model.move(block.id, by: 1) }
            }
            barButton("plus.square.on.square", label: "editor_duplicate") {
                withAnimation { model.duplicate(block.id) }
            }
            barButton("slider.horizontal.3", label: "editor_block_settings") {
                inspectedId = block.id
            }
            barButton("trash", label: "editor_delete_block", tint: AppColors.error) {
                pendingDeleteId = block.id
            }
        }
        .padding(4)
        .background(AppColors.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func barButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        disabled: Bool = false,
        tint: Color = AppColors.onSurface,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(disabled ? AppColors.onSurfaceVariant.opacity(0.4) : tint)
                .frame(width: 34, height: 30)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
        .accessibilityLabel(Text(label))
    }

    private func insertButton(after id: String) -> some View {
        Button {
            insertAfterId = id
            isPickingBlock = true
        } label: {
            HStack(spacing: 6) {
                Rectangle().fill(AppColors.primary.opacity(0.25)).frame(height: 1)
                Label("editor_insert_below", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .fixedSize()
                Rectangle().fill(AppColors.primary.opacity(0.25)).frame(height: 1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var addBlockButton: some View {
        Button {
            insertAfterId = nil
            isPickingBlock = true
        } label: {
            Label("editor_add_block", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Helpers

    private func select(_ id: String) {
        guard model.selectedId != id else { return }
        withAnimation(.easeOut(duration: 0.15)) { model.selectedId = id }
    }

    private func blockBinding(_ id: String) -> Binding<EditableBlock> {
        Binding(
            get: { model.document.blocks.first { $0.id == id } ?? EditableBlock(type: BlockKind.paragraph.rawValue) },
            set: { model.update($0) }
        )
    }

    private struct InspectedBlock: Identifiable {
        let id: String
    }

    private var inspectedBinding: Binding<InspectedBlock?> {
        Binding(
            get: { inspectedId.map(InspectedBlock.init) },
            set: { inspectedId = $0?.id }
        )
    }
}
