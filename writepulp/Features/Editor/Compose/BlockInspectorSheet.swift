//
//  BlockInspectorSheet.swift
//  writepulp
//

import PhotosUI
import SwiftUI

/// Settings of the selected block; the same options the web inspector offers, written to the
/// same `styles` / `properties` keys.
struct BlockInspectorSheet: View {
    @Binding var block: EditableBlock
    let onPickImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var imageItem: PhotosPickerItem?

    private var kind: BlockKind? { block.kind }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("editor_block_type", selection: Binding(
                        get: { kind ?? .paragraph },
                        set: { block.changeType(to: $0) }
                    )) {
                        ForEach(BlockKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .disabled(kind == nil)
                }

                if kind == .header {
                    Section("editor_header_level") {
                        Picker("editor_header_level", selection: Binding(
                            get: { Int(block.propertyNumber("level") ?? 2) },
                            set: { level in
                                block.setProperty("level", .number(Double(level)))
                                block.setStyle("fontSize", BlockPalette.headerSizes[level].map(JSONValue.string))
                            }
                        )) {
                            ForEach(1...6, id: \.self) { Text(verbatim: "H\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if kind?.isText == true { typography }

                if kind == .infoBox {
                    Section("editor_background") {
                        ColorSwatches(colors: BlockPalette.textColors, selection: styleBinding("backgroundColor"))
                    }
                }

                if kind == .quote {
                    Section("editor_background") {
                        ColorSwatches(colors: BlockPalette.quoteBackgrounds, selection: styleBinding("backgroundColor"))
                    }
                }

                if kind == .list {
                    Section("editor_list_style") {
                        Picker("editor_list_style", selection: propertyBinding("listStyle", fallback: "bullet")) {
                            Text("editor_list_bullet").tag("bullet")
                            Text("editor_list_numeric").tag("numeric")
                            Text("editor_list_alpha").tag("alpha")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if kind == .image || kind == .mediaText { imageSettings }

                if kind == .code {
                    Section {
                        Picker("editor_code_language", selection: propertyBinding("language", fallback: "typescript")) {
                            ForEach(BlockPalette.codeLanguages, id: \.self) { Text(verbatim: $0).tag($0) }
                        }
                    }
                }

                if kind == .divider {
                    Section("editor_divider_style") {
                        Picker("editor_divider_style", selection: propertyBinding("dividerStyle", fallback: "solid")) {
                            Text("editor_divider_solid").tag("solid")
                            Text("editor_divider_dotted").tag("dotted")
                            Text("editor_divider_star").tag("star")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if kind == .space {
                    Section {
                        UnitStepper(title: "editor_space_height", value: propertyBinding("spacing", fallback: "20px"), unit: "px", step: 10, range: 0...400)
                    }
                }

                if kind == .reference || kind == .sceneHeading || kind == .dialogue {
                    Section {
                        Text("editor_no_extra_settings")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                }
            }
            .tint(AppColors.primary)
            .navigationTitle(kind?.title ?? "editor_block_settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ok") { dismiss() }
                }
            }
            .onChange(of: imageItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        onPickImage(image)
                    }
                    imageItem = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var typography: some View {
        Section("editor_typography") {
            Picker("editor_align", selection: styleBinding("textAlign", fallback: "left")) {
                Image(systemName: "text.alignleft").tag("left")
                Image(systemName: "text.aligncenter").tag("center")
                Image(systemName: "text.alignright").tag("right")
                Image(systemName: "text.justify").tag("justify")
            }
            .pickerStyle(.segmented)
            UnitStepper(title: "editor_font_size", value: styleBinding("fontSize", fallback: "16px"), unit: "px", step: 1, range: 8...96)
            UnitStepper(title: "editor_indent", value: styleBinding("textIndent", fallback: "0px"), unit: "px", step: 4, range: 0...200)
            UnitStepper(title: "editor_padding", value: styleBinding("contentPadding", fallback: "0px"), unit: "px", step: 4, range: 0...200)
            if kind == .paragraph {
                Toggle("editor_drop_cap", isOn: Binding(
                    get: { block.property("dropCap") == .bool(true) },
                    set: { block.setProperty("dropCap", .bool($0)) }
                ))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("editor_text_color")
                ColorSwatches(colors: BlockPalette.textColors, selection: styleBinding("color"))
            }
        }
    }

    private var imageSettings: some View {
        Section("editor_block_image") {
            PhotosPicker(selection: $imageItem, matching: .images) {
                Label(
                    block.propertyText("url")?.isEmpty == false ? "editor_replace_image" : "editor_pick_image",
                    systemImage: "photo.on.rectangle"
                )
            }
            Picker(kind == .image ? "editor_width" : "editor_image_width", selection: propertyBinding("width", fallback: kind == .image ? "100%" : "36%")) {
                ForEach(["25%", "50%", "75%", "100%"], id: \.self) { Text(verbatim: $0).tag($0) }
                let current = block.propertyText("width") ?? ""
                if !["25%", "50%", "75%", "100%"].contains(current), !current.isEmpty {
                    Text(verbatim: current).tag(current)
                }
            }
            if kind == .image {
                Picker("editor_alignment", selection: propertyBinding("alignment", fallback: "left")) {
                    Image(systemName: "align.horizontal.left").tag("left")
                    Image(systemName: "align.horizontal.center").tag("center")
                    Image(systemName: "align.horizontal.right").tag("right")
                }
                .pickerStyle(.segmented)
                TextField("editor_hint_caption", text: propertyBinding("caption", fallback: ""))
            } else {
                Picker("editor_image_position", selection: propertyBinding("imagePosition", fallback: "left")) {
                    Text("editor_left").tag("left")
                    Text("editor_center").tag("center")
                    Text("editor_right").tag("right")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Bindings

    /// Clearing writes an empty string, as the web inspector does.
    private func styleBinding(_ key: String, fallback: String = "") -> Binding<String> {
        Binding(
            get: { block.styleText(key) ?? fallback },
            set: { block.setStyle(key, .string($0)) }
        )
    }

    private func propertyBinding(_ key: String, fallback: String) -> Binding<String> {
        Binding(
            get: { block.propertyText(key) ?? fallback },
            set: { block.setProperty(key, .string($0)) }
        )
    }
}

/// "16px" style values with − / + buttons.
struct UnitStepper: View {
    let title: LocalizedStringKey
    @Binding var value: String
    let unit: String
    let step: Double
    let range: ClosedRange<Double>

    private var number: Double { EditableBlock.number(value) ?? range.lowerBound }

    var body: some View {
        Stepper(value: Binding(
            get: { number },
            set: { value = "\(Int($0.rounded()))\(unit)" }
        ), in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: value)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
        }
    }
}

/// Color dots plus "none" (an empty value, which falls back to the theme).
struct ColorSwatches: View {
    let colors: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                swatch(nil)
                ForEach(colors, id: \.self) { swatch($0) }
            }
            .padding(.vertical, 4)
        }
    }

    private func swatch(_ hex: String?) -> some View {
        let isSelected = (hex ?? "").caseInsensitiveCompare(selection) == .orderedSame
        return Button { selection = hex ?? "" } label: {
            Circle()
                .fill(hex.flatMap { Color(css: $0) } ?? AppColors.surface)
                .frame(width: 28, height: 28)
                .overlay {
                    if hex == nil {
                        Image(systemName: "slash.circle").foregroundStyle(AppColors.onSurfaceVariant)
                    }
                }
                .overlay { Circle().stroke(AppColors.outline) }
                .overlay {
                    Circle().stroke(AppColors.primary, lineWidth: isSelected ? 2.5 : 0).padding(-3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: hex ?? "none"))
    }
}
