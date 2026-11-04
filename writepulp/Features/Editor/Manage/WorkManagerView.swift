//
//  WorkManagerView.swift
//  writepulp
//

import SwiftUI

/// One work: its chapters (status, lock, delete), new chapter, publish / archive / delete.
@MainActor
struct WorkManagerView: View {
    let navigator: EditorNavigator

    @State private var model: WorkManagerViewModel
    @State private var pendingDelete: WorkSection?
    @State private var isConfirmingWorkDelete = false
    @State private var isConfirmingArchive = false
    @State private var isCreatingTranslation = false
    @State private var editMode = EditMode.inactive

    init(workId: String, service: EditorService, navigator: EditorNavigator) {
        self.navigator = navigator
        _model = State(initialValue: WorkManagerViewModel(workId: workId, service: service))
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if let details = model.details {
                content(details)
                    .overlay(alignment: .bottomTrailing) { floatingButton(details) }
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
                    .frame(maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(model.details?.publication.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let details = model.details {
                ToolbarItem(placement: .topBarTrailing) { menu(details) }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .loadingOverlay(model.isWorking)
        .toast($model.toastMessage)
        .sheet(isPresented: $isCreatingTranslation) {
            if let publication = model.details?.publication {
                CreateTranslationSheet(
                    excludedLanguages: [publication.language] + publication.translations.map(\.language)
                ) { title, language in
                    guard let id = await model.createTranslation(title: title, language: language) else { return false }
                    navigator.open(.work(id: id))
                    return true
                }
            }
        }
        .alert("editor_delete_section_title", isPresented: deleteBinding, presenting: pendingDelete) { section in
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) { Task { await model.delete(section) } }
        } message: { section in
            Text("editor_delete_section_message \(section.title)")
        }
        .alert("editor_delete_work_title", isPresented: $isConfirmingWorkDelete) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                Task { if await model.deleteWork() { navigator.pop() } }
            }
        } message: {
            Text("editor_delete_work_message")
        }
        .alert("editor_archive_work_title", isPresented: $isConfirmingArchive) {
            Button("cancel", role: .cancel) {}
            Button("editor_archive") {
                Task { if await model.archive() { navigator.pop() } }
            }
        } message: {
            Text("editor_archive_work_message")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func content(_ details: WorkDetails) -> some View {
        List {
            Section {
                header(details)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            manageSection(details)

            if details.isOwner, details.publication.originalPublicationId == nil {
                translationsSection(details)
            }

            Section {
                if model.sections.isEmpty {
                    EmptyStateView(
                        systemImage: "doc.badge.plus",
                        title: isSingle(details) ? "editor_no_content_title" : "editor_no_sections_title",
                        message: isSingle(details) ? "editor_no_content_message" : "editor_no_sections_message"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(model.sections.enumerated()), id: \.element.id) { index, section in
                        sectionRow(section, number: index + 1, details: details)
                    }
                    .onMove(perform: isReordering ? { source, destination in
                        Task { await model.moveSections(from: source, to: destination) }
                    } : nil)
                }
            } header: {
                HStack {
                    Text(isSingle(details) ? "editor_content" : "editor_sections")
                    Spacer()
                    if canReorder(details) {
                        Button(isReordering ? "editor_reorder_done" : "editor_reorder") {
                            withAnimation { editMode = isReordering ? .inactive : .active }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        // Room for the floating button under the last row.
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 72) }
    }

    private var isReordering: Bool { editMode == .active }

    private func canReorder(_ details: WorkDetails) -> Bool {
        details.can(.reorderSection) && !isSingle(details) && model.sections.count > 1
    }

    private func manageSection(_ details: WorkDetails) -> some View {
        Section {
            if let originalId = details.publication.originalPublicationId {
                manageRow("editor_view_original", systemImage: "character.book.closed") {
                    // Only the owner can be sure to reach the original's manager.
                    if details.isOwner {
                        navigator.open(.work(id: originalId))
                    } else {
                        navigator.openPublication(originalId)
                    }
                }
            }
            manageRow("editor_team", systemImage: "person.2", value: "\(details.collaborators.count)") {
                navigator.open(.team(workId: model.workId))
            }
            if details.can(.editBookInfo) {
                manageRow("editor_work_settings", systemImage: "slider.horizontal.3") {
                    navigator.open(.workSettings(workId: model.workId))
                }
            }
        }
    }

    private func translationsSection(_ details: WorkDetails) -> some View {
        Section {
            ForEach(details.publication.translations) { translation in
                Button { navigator.open(.work(id: translation.uuid)) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ContentLanguage.displayName(for: translation.language))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.primary)
                            Text(translation.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.onSurface)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        StatusPill(status: translation.status)
                        chevron
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button { isCreatingTranslation = true } label: {
                Label("editor_create_translation", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.primary)
            }
            .disabled(details.publication.status != .published)
            .opacity(details.publication.status == .published ? 1 : 0.5)
        } header: {
            Text("editor_translations")
        } footer: {
            if details.publication.status != .published {
                Text("editor_translation_needs_published")
            }
        }
    }

    private func manageRow(
        _ title: LocalizedStringKey,
        systemImage: String,
        value: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.onSurface)
                Spacer(minLength: 4)
                if let value {
                    Text(verbatim: value)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.onSurfaceVariant)
    }

    /// Article and script have one piece of content: the button creates it once, then edits it.
    private func isSingle(_ details: WorkDetails) -> Bool {
        details.publication.type.isSingleSection
    }

    @ViewBuilder
    private func floatingButton(_ details: WorkDetails) -> some View {
        if isReordering {
            // It would sit over the drag handles.
        } else if isSingle(details), let content = model.sections.first {
            if details.can(.editSection) {
                FloatingCreateButton(title: "editor_edit_content", systemImage: "pencil", action: {
                    navigator.open(.section(workId: model.workId, sectionId: content.id))
                })
            }
        } else if details.can(.createSection) {
            FloatingCreateButton(title: isSingle(details) ? "editor_create_content" : "editor_new_section", action: {
                navigator.open(.section(workId: model.workId, sectionId: nil))
            })
        }
    }

    private func header(_ details: WorkDetails) -> some View {
        let publication = details.publication
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: AppEnvironment.imageURL(publication.coverImg)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            AppColors.primary.opacity(0.12)
                            Image(systemName: publication.type.editorIcon).foregroundStyle(AppColors.primary)
                        }
                    }
                }
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(publication.type.label)
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppColors.primary)
                    Text(publication.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                    HStack(spacing: 8) {
                        StatusPill(status: publication.status)
                        Text(publication.type.isSingleSection
                             ? "editor_words_count \(model.totalWords)"
                             : "editor_sections_words \(model.sections.count) \(Formatters.compactCount(model.totalWords))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                }
            }
            HStack(spacing: 10) {
                if details.isOwner {
                    let isPublished = publication.status == .published
                    actionButton(
                        isPublished ? "editor_unpublish" : "editor_publish",
                        systemImage: isPublished ? "eye.slash" : "paperplane",
                        filled: !isPublished
                    ) {
                        Task { await model.togglePublish() }
                    }
                }
            }
        }
    }

    private func actionButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(filled ? AppColors.onPrimary : AppColors.primary)
                .background(filled ? AppColors.primary : AppColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func sectionRow(_ section: WorkSection, number: Int, details: WorkDetails) -> some View {
        Button {
            guard !isReordering else { return }
            navigator.open(.section(workId: model.workId, sectionId: section.id))
        } label: {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 28, height: 28)
                    .background(AppColors.primary.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(section.title.isEmpty ? String(localized: "editor_untitled_section") : section.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.onSurface)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if section.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                    HStack(spacing: 8) {
                        StatusPill(status: section.status)
                        Text("editor_words_count \(section.wordCount)")
                        Text(Formatters.timeAgo(section.updatedAt))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                }
                Spacer(minLength: 4)
                if !isReordering {
                    sectionMenu(section, details: details)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if details.can(.deleteSection) {
                Button(role: .destructive) { pendingDelete = section } label: { Label("delete", systemImage: "trash") }
            }
        }
    }

    private func sectionMenu(_ section: WorkSection, details: WorkDetails) -> some View {
        Menu {
            if details.can(.editSection) {
                Button { navigator.open(.section(workId: model.workId, sectionId: section.id)) } label: {
                    Label("editor_edit", systemImage: "pencil")
                }
            }
            if details.can(.publishSection) {
                Picker(selection: Binding(
                    get: { section.status },
                    set: { status in Task { await model.setStatus(status, of: section) } }
                )) {
                    ForEach(WorkStatus.sectionChoices, id: \.self) { Text($0.label).tag($0) }
                } label: {
                    Label("editor_section_status", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
            }
            // The backend lets only the owner and co-authors lock; of the roles, only they hold this permission.
            if details.can(.editBookInfo) {
                Button { Task { await model.toggleLock(section) } } label: {
                    Label(section.isLocked ? "editor_unlock" : "editor_lock", systemImage: section.isLocked ? "lock.open" : "lock")
                }
            }
            if details.can(.deleteSection) {
                Divider()
                Button(role: .destructive) { pendingDelete = section } label: { Label("delete", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }

    private func menu(_ details: WorkDetails) -> some View {
        Menu {
            if details.can(.archiveBook) {
                Button { isConfirmingArchive = true } label: { Label("editor_archive", systemImage: "archivebox") }
            }
            if details.can(.deleteBook) {
                Button(role: .destructive) { isConfirmingWorkDelete = true } label: {
                    Label("editor_delete_work", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(!details.can(.archiveBook) && !details.can(.deleteBook))
    }
}
