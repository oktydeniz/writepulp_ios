//
//  SectionSettingsSheet.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// Section-level settings: access, the magazine hero, and the reader defaults saved in `doc.reader`.
struct SectionSettingsSheet: View {
    @Bindable var model: SectionComposerViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var coverItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                if model.canSetAccess {
                    Section {
                        Toggle("editor_section_free", isOn: $model.draft.isFree)
                    } footer: {
                        Text("editor_section_free_footer")
                    }
                }

                if model.isMagazine { hero }

                Section("editor_reader_defaults") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("editor_theme")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ReaderTheme.all) { theme in
                                    Button { model.themeId = theme.id } label: {
                                        Text("Aa")
                                            .font(.system(size: 14, weight: .semibold, design: .serif))
                                            .foregroundStyle(theme.text)
                                            .frame(width: 44, height: 44)
                                            .background(theme.background, in: RoundedRectangle(cornerRadius: 10))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(model.themeId == theme.id ? AppColors.primary : AppColors.outline,
                                                            lineWidth: model.themeId == theme.id ? 2.5 : 1)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(verbatim: theme.name))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Picker("editor_font", selection: $model.fontId) {
                        ForEach(ReaderFont.all) { Text(verbatim: $0.name).tag($0.id) }
                    }
                    Stepper(value: $model.fontSize, in: 12...28, step: 1) {
                        HStack {
                            Text("editor_font_size")
                            Spacer()
                            Text(verbatim: "\(Int(model.fontSize))px")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                }

                Section("editor_document") {
                    LabeledContent("editor_blocks_count", value: "\(model.document.blocks.count)")
                    LabeledContent("editor_words", value: "\(model.wordCount)")
                    LabeledContent("editor_minutes", value: "\(model.readingMinutes)")
                }
            }
            .tint(AppColors.primary)
            .navigationTitle("editor_section_settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ok") { dismiss() }
                }
            }
            .onChange(of: coverItem) { _, item in
                guard let item else { return }
                Task {
                    await model.uploadCover(from: item)
                    coverItem = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
        .toast($model.toastMessage)
    }

    private var hero: some View {
        // The picker's label closure is not main-actor isolated.
        let hasCover = model.draft.coverImg != nil
        return Section("editor_hero") {
            TextField("editor_subtitle", text: Binding(
                get: { model.draft.subtitle ?? "" },
                set: { model.draft.subtitle = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            Picker("editor_page_type", selection: Binding(
                get: { model.draft.pageType ?? "GENERAL" },
                set: { model.draft.pageType = $0 }
            )) {
                ForEach(BlockPalette.pageTypes, id: \.self) { type in
                    // A String variable, so the key is looked up as is (an interpolated literal would become a format key).
                    let key = "editor_page_type_" + type.lowercased()
                    Text(LocalizedStringKey(key)).tag(type)
                }
            }
            HStack(spacing: 12) {
                ZStack {
                    ComposerCoverImage(local: model.localCover, path: model.draft.coverImg)
                    if model.draft.coverImg == nil, model.localCover == nil {
                        Image(systemName: "photo").foregroundStyle(AppColors.primary)
                    }
                    if model.uploadingIds.contains("cover") {
                        Color.black.opacity(0.35)
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 72, height: 48)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                PhotosPicker(selection: $coverItem, matching: .images) {
                    Text(hasCover ? "editor_replace_image" : "editor_pick_image")
                }
                .buttonStyle(.borderless)
                .disabled(model.uploadingIds.contains("cover"))
                Spacer()
                if model.draft.coverImg != nil {
                    Button("editor_remove", role: .destructive) { model.removeCover() }
                        .buttonStyle(.borderless)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("editor_hero_color")
                ColorSwatches(colors: BlockPalette.textColors, selection: Binding(
                    get: { model.draft.heroColor ?? "" },
                    set: { model.draft.heroColor = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }
}

/// The cover just picked, or the saved one. Failing to load shows an icon instead of spinning forever.
struct ComposerCoverImage: View {
    let local: UIImage?
    let path: String?

    var body: some View {
        if let local {
            Image(uiImage: local).resizable().scaledToFill()
        } else if let url = AppEnvironment.imageURL(path) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.white.opacity(0.8))
                } else {
                    ProgressView()
                }
            }
        }
    }
}

/// A magazine page's hero: cover or color, page type, title and subtitle, as the reader opens it.
struct MagazineHeroCard: View {
    let title: String
    let draft: SectionDraft
    let localCover: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // As an overlay, a filling image can't grow the card past its frame.
            (Color(css: draft.heroColor) ?? PlaceholderColor.color(for: title))
                .overlay { ComposerCoverImage(local: localCover, path: draft.coverImg) }
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                let key = "editor_page_type_" + (draft.pageType ?? "GENERAL").lowercased()
                Text(LocalizedStringKey(key))
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                if let subtitle = draft.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }
            .padding(14)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// The section rendered by the reader, with the chosen reader defaults.
struct ComposerPreviewSheet: View {
    let title: String
    /// Set for magazine pages; they open with their hero instead of a plain title.
    var hero: SectionDraft?
    var localCover: UIImage?
    let document: EditableDocument
    let themeId: String
    let fontId: String
    let fontSize: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = ReaderTheme.byId(themeId)
        let style = ReaderStyle(theme: theme, font: .byId(fontId), fontSize: CGFloat(fontSize), lineHeight: 1.7)
        let blocks = EditorDocument.parse(try? document.encoded()).blocks
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let hero {
                        MagazineHeroCard(title: title, draft: hero, localCover: localCover)
                    } else {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(theme.text)
                    }
                    ReaderBlocks(blocks: blocks, style: style)
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("editor_preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ok") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}
