//
//  BlockEditorRow.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// One block as it is written: text blocks edit in place styled like the reader shows them,
/// media and layout blocks show a stand-in with their own controls.
struct BlockEditorRow: View {
    @Binding var block: EditableBlock
    let isSelected: Bool
    let isUploading: Bool
    let onSelect: () -> Void
    let onSettings: () -> Void
    let onPickImage: (UIImage) -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.primary.opacity(0.05) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primary.opacity(0.6) : .clear, lineWidth: 1.2)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .header: header
        case .paragraph, .poem: text()
        case .list: list
        case .quote: quote
        case .infoBox: infoBox
        case .image: ImageBlockEditor(block: $block, isUploading: isUploading, onPick: onPickImage)
        case .mediaText: mediaText
        case .divider: divider
        case .space: space
        case .code: code
        case .reference: ReferenceBlockEditor(block: $block)
        case .sceneHeading: sceneHeading
        case .dialogue: dialogue
        case nil: unsupported
        }
    }

    // MARK: - Text

    private var contentBinding: Binding<String> {
        Binding(get: { block.content }, set: { block.content = $0 })
    }

    private var alignment: NSTextAlignment {
        switch block.styleText("textAlign") {
        case "center": .center
        case "right": .right
        case "justify": .justified
        default: .natural
        }
    }

    /// Block px size shown at a phone-friendly scale.
    private func fontSize(fallback: Double) -> CGFloat {
        CGFloat(min(max(block.styleNumber("fontSize") ?? fallback, 12), 40))
    }

    private var weight: UIFont.Weight {
        switch Int(block.styleText("fontWeight") ?? "") ?? 400 {
        case 700...: .bold
        case 600..<700: .semibold
        case 500..<600: .medium
        default: .regular
        }
    }

    private func uiFont(size: CGFloat, weight: UIFont.Weight, serif: Bool = false, italic: Bool = false, mono: Bool = false) -> UIFont {
        var font = mono ? UIFont.monospacedSystemFont(ofSize: size, weight: weight) : UIFont.systemFont(ofSize: size, weight: weight)
        var descriptor = font.fontDescriptor
        if serif, let serifDescriptor = descriptor.withDesign(.serif) { descriptor = serifDescriptor }
        if italic, let italicDescriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = italicDescriptor
        }
        font = UIFont(descriptor: descriptor, size: size)
        return font
    }

    private func text(
        placeholder: LocalizedStringResource = "editor_hint_paragraph",
        font: UIFont? = nil
    ) -> some View {
        let isPoem = block.kind == .poem
        return MarkupTextView(
            text: contentBinding,
            placeholder: String(localized: isPoem ? "editor_hint_poem" : placeholder),
            font: font ?? uiFont(size: fontSize(fallback: 16), weight: weight, serif: isPoem, italic: isPoem),
            alignment: alignment,
            allowsFormatting: block.kind?.allowsFormatting ?? true,
            onFocus: onSelect,
            onSettings: onSettings
        )
        .padding(.leading, CGFloat(block.styleNumber("textIndent") ?? 0).clamped(to: 0...80))
        .overlay(alignment: .topLeading) {
            if block.propertyText("dropCap") == "true" {
                Text("editor_drop_cap_badge")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .offset(x: -6, y: -10)
            }
        }
    }

    private var header: some View {
        let level = Int(block.propertyNumber("level") ?? 2)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "H\(level)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            text(
                placeholder: "editor_hint_header",
                font: uiFont(size: fontSize(fallback: 32) * 0.8, weight: .bold, serif: true)
            )
        }
    }

    private var list: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: block.propertyText("listStyle") == "numeric" ? "list.number" : "list.bullet")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.primary)
                .padding(.top, 3)
            text(placeholder: "editor_hint_list")
        }
    }

    private var quote: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(AppColors.primary).frame(width: 3)
            text(placeholder: "editor_hint_quote", font: uiFont(size: fontSize(fallback: 16) + 1, weight: weight, serif: true, italic: true))
        }
        .padding(10)
        .background(quoteBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var quoteBackground: Color {
        guard let css = block.styleText("backgroundColor"), !css.hasPrefix("theme:"), css.uppercased() != "#FFFFFF" else {
            return AppColors.background
        }
        return (Color(css: css) ?? AppColors.background).opacity(0.5)
    }

    private var infoBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppColors.primary)
                .padding(.top, 2)
            text(placeholder: "editor_hint_info")
        }
        .padding(12)
        .background(
            (Color(css: block.styleText("backgroundColor")) ?? AppColors.primary).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var mediaText: some View {
        let imageOnRight = block.propertyText("imagePosition") == "right"
        let image = ImageBlockEditor(block: $block, isUploading: isUploading, compact: true, onPick: onPickImage)
            .frame(width: 110)
        return HStack(alignment: .top, spacing: 12) {
            if !imageOnRight { image }
            text(placeholder: "editor_hint_media_text")
            if imageOnRight { image }
        }
    }

    private var code: some View {
        MarkupTextView(
            text: contentBinding,
            placeholder: "code",
            font: .monospacedSystemFont(ofSize: 14, weight: .regular),
            textColor: UIColor(white: 0.92, alpha: 1),
            allowsFormatting: false,
            autocapitalization: .none,
            onFocus: onSelect,
            onSettings: onSettings
        )
        .padding(12)
        .background(Color(hex: 0x1E293B), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            Text(verbatim: block.propertyText("language") ?? "")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .padding(6)
        }
    }

    private var sceneHeading: some View {
        TextField("editor_hint_scene", text: contentBinding, axis: .vertical)
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .textInputAutocapitalization(.characters)
            .onTapGesture(perform: onSelect)
    }

    private var dialogue: some View {
        VStack(spacing: 6) {
            TextField("editor_hint_character", text: Binding(
                get: { block.propertyText("character") ?? "" },
                set: { block.setProperty("character", .string($0)) }
            ))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .textInputAutocapitalization(.characters)
            .multilineTextAlignment(.center)
            text(placeholder: "editor_hint_dialogue")
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Layout

    private var divider: some View {
        Group {
            switch block.propertyText("dividerStyle") {
            case "star":
                Text(verbatim: "* * *")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
            case "dotted":
                Line().stroke(AppColors.onSurfaceVariant, style: StrokeStyle(lineWidth: 2, dash: [2, 5])).frame(height: 2)
            default:
                Line().stroke(AppColors.onSurfaceVariant.opacity(0.6), lineWidth: 1).frame(height: 1)
            }
        }
        .padding(.vertical, 8)
    }

    private var space: some View {
        let height = CGFloat(block.propertyNumber("spacing") ?? 20)
        return RoundedRectangle(cornerRadius: 6)
            .stroke(AppColors.outline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: min(max(height, 16), 120))
            .overlay {
                Text(verbatim: block.propertyText("spacing") ?? "20px")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
    }

    private var unsupported: some View {
        Label {
            Text("editor_unsupported_block \(block.type)")
        } icon: {
            Image(systemName: "puzzlepiece.extension")
        }
        .font(.system(size: 13))
        .foregroundStyle(AppColors.onSurfaceVariant)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}

// MARK: - Image

/// Image of an image or media-text block: the uploaded picture, or a picker when there is none.
struct ImageBlockEditor: View {
    @Binding var block: EditableBlock
    let isUploading: Bool
    var compact = false
    let onPick: (UIImage) -> Void

    @State private var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $item, matching: .images) {
                ZStack {
                    if let url = AppEnvironment.imageURL(block.propertyText("url")) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else if phase.error != nil {
                                placeholder(systemImage: "exclamationmark.triangle")
                            } else {
                                ProgressView().frame(maxWidth: .infinity, minHeight: compact ? 90 : 160)
                            }
                        }
                    } else {
                        placeholder(systemImage: "photo.badge.plus")
                    }
                    if isUploading {
                        Color.black.opacity(0.35)
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isUploading)

            if !compact {
                TextField("editor_hint_caption", text: Binding(
                    get: { block.propertyText("caption") ?? "" },
                    set: { block.setProperty("caption", $0.isEmpty ? nil : .string($0)) }
                ))
                .font(.system(size: 13))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            }
        }
        .onChange(of: item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    onPick(image)
                }
                self.item = nil
            }
        }
    }

    private func placeholder(systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: compact ? 20 : 28))
            if !compact {
                Text("editor_pick_image").font(.system(size: 13, weight: .medium))
            }
        }
        .foregroundStyle(AppColors.primary)
        .frame(maxWidth: .infinity, minHeight: compact ? 90 : 160)
        .background(AppColors.primary.opacity(0.08))
    }
}

// MARK: - Reference

/// Bibliography rows; the block's content is a JSON array of {author, year, title, url}.
struct ReferenceBlockEditor: View {
    @Binding var block: EditableBlock

    private var rows: [[String: JSONValue]] {
        guard let data = block.content.data(using: .utf8),
              case .array(let items)? = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return [] }
        return items.compactMap(\.objectValue)
    }

    private func write(_ rows: [[String: JSONValue]]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? encoder.encode(JSONValue.array(rows.map(JSONValue.object))) {
            block.content = String(decoding: data, as: UTF8.self)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("editor_block_reference", systemImage: "books.vertical")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.primary)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, _ in
                VStack(spacing: 6) {
                    HStack {
                        field(index, "author", placeholder: "editor_ref_author")
                        field(index, "year", placeholder: "editor_ref_year").frame(width: 70)
                        Button {
                            var next = rows
                            next.remove(at: index)
                            write(next)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.onSurfaceVariant)
                        }
                        .buttonStyle(.plain)
                    }
                    field(index, "title", placeholder: "editor_ref_title")
                    field(index, "url", placeholder: "https://")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                .padding(10)
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: 8))
            }
            Button {
                write(rows + [["author": .string(""), "year": .string(""), "title": .string(""), "url": .string("")]])
            } label: {
                Label("editor_ref_add", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
        }
    }

    private func field(_ index: Int, _ key: String, placeholder: LocalizedStringKey) -> some View {
        TextField(placeholder, text: Binding(
            get: { rows.indices.contains(index) ? rows[index][key]?.stringValue ?? "" : "" },
            set: { value in
                var next = rows
                guard next.indices.contains(index) else { return }
                next[index][key] = .string(value)
                write(next)
            }
        ))
        .font(.system(size: 14))
        .textFieldStyle(.roundedBorder)
    }
}
