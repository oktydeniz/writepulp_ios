//
//  ReaderPreferences.swift
//  writepulp
//

import Foundation
import Observation

@Observable
final class ReaderPreferences {
    static let defaultTheme = "light"
    static let defaultFont = "serif"
    static let defaultFontSize = 18
    static let defaultLineHeight = 1.8

    private enum Key {
        static let theme = "reader_theme_key"
        static let font = "reader_font_key"
        static let fontSize = "reader_font_size_key"
        static let lineHeight = "reader_line_height_key"
    }

    private let defaults: UserDefaults

    private(set) var theme = ReaderPreferences.defaultTheme
    private(set) var font = ReaderPreferences.defaultFont
    private(set) var fontSize = ReaderPreferences.defaultFontSize
    private(set) var lineHeight = ReaderPreferences.defaultLineHeight

    init(defaults: UserDefaults) {
        self.defaults = defaults
        reload()
    }

    func reload() {
        theme = defaults.string(forKey: Key.theme) ?? Self.defaultTheme
        font = defaults.string(forKey: Key.font) ?? Self.defaultFont
        fontSize = defaults.object(forKey: Key.fontSize) as? Int ?? Self.defaultFontSize
        lineHeight = defaults.object(forKey: Key.lineHeight) as? Double ?? Self.defaultLineHeight
    }

    func setTheme(_ themeId: String) {
        defaults.set(themeId, forKey: Key.theme)
        theme = themeId
    }

    func setFont(_ fontId: String) {
        defaults.set(fontId, forKey: Key.font)
        font = fontId
    }

    func setFontSize(_ size: Int) {
        defaults.set(size, forKey: Key.fontSize)
        fontSize = size
    }

    func setLineHeight(_ height: Double) {
        defaults.set(height, forKey: Key.lineHeight)
        lineHeight = height
    }
}
