//
//  BlockKind.swift
//  writepulp
//

import SwiftUI

/// The block types the editor can create, with the defaults the web editor gives a new block.
/// Blocks of other types still open and save unchanged; they just can't be edited.
enum BlockKind: String, CaseIterable, Identifiable {
    case paragraph, header, quote
    case infoBox = "info-box"
    case list, poem, image
    case mediaText = "media-text"
    case divider, space, code, reference
    case sceneHeading = "scene-heading"
    case dialogue

    var id: String { rawValue }

    enum Group: CaseIterable, Identifiable {
        case text, media, layout, special

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .text: "editor_group_text"
            case .media: "editor_group_media"
            case .layout: "editor_group_layout"
            case .special: "editor_group_special"
            }
        }

        var kinds: [BlockKind] {
            switch self {
            case .text: [.paragraph, .header, .quote, .infoBox, .list, .poem]
            case .media: [.image, .mediaText]
            case .layout: [.divider, .space]
            case .special: [.code, .reference, .sceneHeading, .dialogue]
            }
        }
    }

    var title: LocalizedStringKey { LocalizedStringKey(localizationKey) }
    var localizedName: String { String(localized: String.LocalizationValue(localizationKey)) }

    private var localizationKey: String {
        switch self {
        case .paragraph: "editor_block_paragraph"
        case .header: "editor_block_header"
        case .quote: "editor_block_quote"
        case .infoBox: "editor_block_info_box"
        case .list: "editor_block_list"
        case .poem: "editor_block_poem"
        case .image: "editor_block_image"
        case .mediaText: "editor_block_media_text"
        case .divider: "editor_block_divider"
        case .space: "editor_block_space"
        case .code: "editor_block_code"
        case .reference: "editor_block_reference"
        case .sceneHeading: "editor_block_scene_heading"
        case .dialogue: "editor_block_dialogue"
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph: "text.alignleft"
        case .header: "textformat.size"
        case .quote: "quote.opening"
        case .infoBox: "info.circle"
        case .list: "list.bullet"
        case .poem: "leaf"
        case .image: "photo"
        case .mediaText: "rectangle.split.2x1"
        case .divider: "minus"
        case .space: "arrow.up.and.down"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .reference: "books.vertical"
        case .sceneHeading: "film"
        case .dialogue: "person.wave.2"
        }
    }

    /// Text blocks with typography settings (web `TEXT_BLOCK_TYPES`).
    var isText: Bool {
        switch self {
        case .header, .paragraph, .quote, .infoBox, .mediaText, .list, .poem: true
        default: false
        }
    }

    /// Blocks counted in the word count (web `WORD_BLOCK_TYPES`).
    var countsWords: Bool { isText || self == .sceneHeading || self == .dialogue }

    /// Inline markup (bold, italic, link, color) is meaningful here.
    var allowsFormatting: Bool { isText || self == .dialogue }

    /// Same defaults as the web editor's `getNewBlock`.
    func makeBlock() -> EditableBlock {
        let content = switch self {
        case .code: "const hello = \"world\";"
        case .sceneHeading: "INT. LOCATION - DAY"
        default: ""
        }
        var block = EditableBlock(type: rawValue, content: content)
        block.setStyle("fontSize", .string(self == .header ? "32px" : "16px"))
        block.setStyle("fontWeight", .string(self == .header || self == .sceneHeading ? "700" : "400"))
        block.setStyle("contentPadding", .string("0px"))
        if self == .quote { block.setStyle("backgroundColor", .string(BlockPalette.quoteBackgrounds[0])) }
        block.setProperty("level", .number(2))
        block.setProperty("alignment", .string(self == .dialogue ? "center" : "left"))
        block.setProperty("language", .string("typescript"))
        block.setProperty("dividerStyle", .string("solid"))
        block.setProperty("width", .string("100%"))
        block.setProperty("spacing", .string("20px"))
        block.setProperty("listStyle", .string("bullet"))
        if self == .dialogue { block.setProperty("character", .string("")) }
        return block
    }
}

/// Colors the web editor offers, so both editors write the same values.
enum BlockPalette {
    static let textColors = [
        "#111827", "#1F2937", "#374151", "#6B7280", "#DC2626", "#EA580C",
        "#CA8A04", "#16A34A", "#0891B2", "#2563EB", "#7C3AED", "#DB2777",
    ]
    /// Reader theme backgrounds (web `READING_THEMES`).
    static let quoteBackgrounds = ["#FFFFFF", "#F5ECD9", "#121212", "#E8F5E9", "#F0F0F0", "#E0F7FA", "#FFF8E1", "#0D1B2A"]
    static let codeLanguages = ["typescript", "javascript", "tsx", "jsx", "json", "python", "java", "kotlin", "swift", "go", "other"]
    static let pageTypes = ["GENERAL", "EDITORIAL", "FEATURE", "POETRY", "INTERVIEW", "SCENE"]
    /// Header level → font size, as the web sets it.
    static let headerSizes = [1: "36px", 2: "32px", 3: "28px", 4: "24px", 5: "20px", 6: "16px"]
}

extension EditableBlock {
    var kind: BlockKind? { BlockKind(rawValue: type) }

    func styleText(_ key: String) -> String? { style(key)?.stringValue }
    func propertyText(_ key: String) -> String? { property(key)?.stringValue }

    /// A px / % value as a number ("32px" → 32); legacy documents may store plain numbers.
    func styleNumber(_ key: String) -> Double? { Self.number(styleText(key)) }
    func propertyNumber(_ key: String) -> Double? { Self.number(propertyText(key)) }

    static func number(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        return Double(raw.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces))
    }

    /// A copy with a new id, for "duplicate".
    func duplicated() -> EditableBlock {
        var raw = raw
        raw["id"] = .string(UUID().uuidString.lowercased())
        return EditableBlock(raw: raw)
    }

    /// Changes the type, keeping content and settings (quotes get a reader-theme background as on the web).
    mutating func changeType(to kind: BlockKind) {
        var raw = raw
        raw["type"] = .string(kind.rawValue)
        self = EditableBlock(raw: raw)
        if kind == .quote {
            let background = styleText("backgroundColor") ?? ""
            if !BlockPalette.quoteBackgrounds.contains(background) || background.hasPrefix("theme:") {
                setStyle("backgroundColor", .string(BlockPalette.quoteBackgrounds[0]))
            }
        }
    }

    /// Plain words of the block, without inline markup.
    var wordCount: Int {
        guard kind?.countsWords == true else { return 0 }
        return MarkupText.plain(content).split(whereSeparator: \.isWhitespace).count
    }
}

/// Inline markup of block text: `**bold**`, `*italic*`, `[label](url)`, `<c:#hex>text</c>`.
enum MarkupText {
    static func plain(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"<c:[^>]*>|</c>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "*", with: "")
    }
}
