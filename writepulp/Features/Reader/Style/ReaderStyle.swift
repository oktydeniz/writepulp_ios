//
//  ReaderStyle.swift
//  writepulp
//

import SwiftUI

struct ReaderTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let background: Color
    let text: Color
    let accent: Color
    let isDark: Bool

    static let all: [ReaderTheme] = [
        ReaderTheme(id: "light", name: "Light", background: Color(hex: 0xFFFFFF), text: Color(hex: 0x000000), accent: Color(hex: 0xD0D0D0), isDark: false),
        ReaderTheme(id: "sepia", name: "Sepia", background: Color(hex: 0xF5ECD9), text: Color(hex: 0x3B2F2F), accent: Color(hex: 0xC3B091), isDark: false),
        ReaderTheme(id: "dark", name: "Dark", background: Color(hex: 0x121212), text: Color(hex: 0xE0E0E0), accent: Color(hex: 0x303030), isDark: true),
        ReaderTheme(id: "mint", name: "Mint", background: Color(hex: 0xE8F5E9), text: Color(hex: 0x1B3A2B), accent: Color(hex: 0xA5D6A7), isDark: false),
        ReaderTheme(id: "gray", name: "Gray", background: Color(hex: 0xF0F0F0), text: Color(hex: 0x1C1C1C), accent: Color(hex: 0xC0C0C0), isDark: false),
        ReaderTheme(id: "ocean", name: "Ocean", background: Color(hex: 0xE0F7FA), text: Color(hex: 0x004D40), accent: Color(hex: 0x80DEEA), isDark: false),
        ReaderTheme(id: "sand", name: "Sand", background: Color(hex: 0xFFF8E1), text: Color(hex: 0x4E342E), accent: Color(hex: 0xFFD54F), isDark: false),
        ReaderTheme(id: "night_blue", name: "Night Blue", background: Color(hex: 0x0D1B2A), text: Color(hex: 0xB0BEC5), accent: Color(hex: 0x1B263B), isDark: true),
    ]

    static let nightBlue = all.first { $0.id == "night_blue" }!

    static func byId(_ id: String) -> ReaderTheme {
        all.first { $0.id == id } ?? all[0]
    }

    var secondaryText: Color { text.opacity(0.7) }

    var reviewsPalette: ReviewsPalette {
        ReviewsPalette(
            title: text,
            text: text,
            secondaryText: text.opacity(0.65),
            card: accent.opacity(0.12),
            fieldBackground: background,
            outline: text.opacity(0.18),
            accent: AppColors.primary
        )
    }
}

struct ReaderFont: Identifiable, Equatable {
    enum Source: Equatable {
        case system(Font.Design)
        case custom(String)
    }

    let id: String
    let name: String
    let source: Source

    static let all: [ReaderFont] = [
        ReaderFont(id: "default", name: "Default", source: .system(.default)),
        ReaderFont(id: "serif", name: "Serif", source: .system(.serif)),
        ReaderFont(id: "sansserif", name: "Sans Serif", source: .system(.default)),
        ReaderFont(id: "cursive", name: "Cursive", source: .custom("SnellRoundhand")),
        ReaderFont(id: "opensans", name: "Open Sans", source: .custom("Open Sans")),
        ReaderFont(id: "notoserif", name: "Noto Serif", source: .custom("Noto Serif")),
        ReaderFont(id: "lora", name: "Lora", source: .custom("Lora")),
        ReaderFont(id: "ptserif", name: "PT Serif", source: .custom("PT Serif")),
        ReaderFont(id: "roboto", name: "Roboto", source: .system(.default)),
        ReaderFont(id: "rubik", name: "Rubik", source: .custom("Rubik")),
    ]

    static func byId(_ id: String) -> ReaderFont {
        all.first { $0.id == id } ?? all[1]
    }

    func font(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        var font: Font
        switch source {
        case .system(let design):
            font = .system(size: size, weight: weight, design: design)
        case .custom(let name):
            font = .custom(name, fixedSize: size).weight(weight)
        }
        return italic ? font.italic() : font
    }

    func uiFont(size: CGFloat, bold: Bool = false, italic: Bool = false) -> UIFont {
        var descriptor: UIFontDescriptor
        switch source {
        case .system(let design):
            descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            if design == .serif, let serif = descriptor.withDesign(.serif) { descriptor = serif }
        case .custom(let name):
            descriptor = (UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)).fontDescriptor
        }
        var traits = descriptor.symbolicTraits
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        descriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// Everything a block needs to render: the active theme, font and the user's size settings.
struct ReaderStyle {
    let theme: ReaderTheme
    let font: ReaderFont
    let fontSize: CGFloat
    let lineHeight: CGFloat

    /// Blocks declare px sizes relative to a 16px base; they scale with the reader's font size.
    func size(for blockFontSize: String?) -> CGFloat {
        guard let raw = blockFontSize?.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces),
              let px = Double(raw), px > 0 else { return fontSize }
        return fontSize * CGFloat(px / 16)
    }

    func lineSpacing(for size: CGFloat, multiplier: CGFloat? = nil) -> CGFloat {
        // A font's natural line height is about 1.2x its size; the rest is extra spacing.
        max(0, size * ((multiplier ?? lineHeight) - 1.2))
    }

    /// Only the light theme keeps a block's own text color; other themes would make it unreadable.
    /// A block with its own opaque background (e.g. quotes saved with a white one) gets text that
    /// reads on that background instead of the theme's text color.
    func textColor(_ blockColor: String?, background: String? = nil) -> Color {
        if theme.id == "light", let color = Color(css: blockColor) { return color }
        if let background, !background.hasPrefix("theme:"),
           let rgb = CSSColor.rgba(background), rgb.alpha > 0.3 {
            return CSSColor.isLight(rgb) ? Color(hex: 0x1C1C1C) : Color(hex: 0xF0F0F0)
        }
        return theme.text
    }

    /// "theme:<id>" means no custom background.
    func background(_ blockBackground: String?) -> Color {
        guard let blockBackground, !blockBackground.hasPrefix("theme:") else { return .clear }
        return Color(css: blockBackground) ?? .clear
    }
}

extension ReaderPreferences {
    /// Dark app appearance always reads in Night Blue.
    func style(colorScheme: ColorScheme) -> ReaderStyle {
        ReaderStyle(
            theme: colorScheme == .dark ? .nightBlue : .byId(theme),
            font: .byId(font),
            fontSize: CGFloat(fontSize),
            lineHeight: CGFloat(lineHeight)
        )
    }
}

enum TextAlignmentValue {
    static func horizontal(_ value: String?) -> HorizontalAlignment {
        switch value {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
    }

    static func text(_ value: String?) -> TextAlignment {
        switch value {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
    }

    static func frame(_ value: String?) -> Alignment {
        switch value {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
    }
}

enum CSSColor {
    typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    /// "#RGB", "#RRGGBB", "#RRGGBBAA", "rgb(r, g, b)" and "rgba(r, g, b, a)", components 0...1.
    static func rgba(_ value: String?) -> RGBA? {
        guard var text = value?.trimmingCharacters(in: .whitespaces).lowercased(), !text.isEmpty else { return nil }
        if text.hasPrefix("rgb") {
            guard let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")") else { return nil }
            let parts = text[text.index(after: open)..<close]
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count >= 3 else { return nil }
            return (parts[0] / 255, parts[1] / 255, parts[2] / 255, parts.count > 3 ? parts[3] : 1)
        }
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6 || text.count == 8, let raw = UInt64(text, radix: 16) else { return nil }
        let rgb = text.count == 8 ? raw >> 8 : raw
        let alpha = text.count == 8 ? Double(raw & 0xFF) / 255 : 1
        return (Double((rgb >> 16) & 0xFF) / 255, Double((rgb >> 8) & 0xFF) / 255, Double(rgb & 0xFF) / 255, alpha)
    }

    /// Perceived brightness above the middle.
    static func isLight(_ color: RGBA) -> Bool {
        0.299 * color.red + 0.587 * color.green + 0.114 * color.blue > 0.6
    }
}

extension Color {
    init?(css value: String?) {
        guard let rgb = CSSColor.rgba(value) else { return nil }
        self = Color(red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.alpha)
    }
}
