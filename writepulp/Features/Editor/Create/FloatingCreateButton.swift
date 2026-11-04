//
//  FloatingCreateButton.swift
//  writepulp
//

import SwiftUI

extension PublicationType {
    /// The types a writer can start, in the web's order (open book is not offered yet).
    static let writable: [PublicationType] = [.book, .article, .magazine, .script]

    /// Article and script hold a single piece of content instead of a chapter list.
    var isSingleSection: Bool { self == .article || self == .script }

    var editorIcon: String {
        switch self {
        case .book, .openBook: "book"
        case .article: "doc.text"
        case .magazine: "newspaper"
        case .script: "scroll"
        }
    }

    var editorTint: Color {
        switch self {
        case .book, .openBook: Color(red: 0x60 / 255, green: 0x80 / 255, blue: 0x9E / 255)
        case .article: Color(red: 0x3D / 255, green: 0xAA / 255, blue: 0x72 / 255)
        case .magazine: Color(red: 0x7C / 255, green: 0x5C / 255, blue: 0xBF / 255)
        case .script: Color(red: 0x9B / 255, green: 0x59 / 255, blue: 0xB6 / 255)
        }
    }

    var editorDescription: LocalizedStringKey {
        switch self {
        case .book, .openBook: "editor_type_book_desc"
        case .article: "editor_type_article_desc"
        case .magazine: "editor_type_magazine_desc"
        case .script: "editor_type_script_desc"
        }
    }
}

extension SessionStore {
    /// Readers have to switch to an author account before they can write.
    var canWrite: Bool {
        guard isLoggedIn, let role, !role.isEmpty else { return false }
        return role != "READER"
    }
}

/// A round "+" button for the bottom-right corner, in Liquid Glass like the tab bar. With `options`
/// it opens the system menu of work types; without, it runs `action` straight away.
@MainActor
struct FloatingCreateButton: View {
    var title: LocalizedStringKey = "editor_new_work"
    var systemImage = "plus"
    var options: [PublicationType] = []
    var onPick: (PublicationType) -> Void = { _ in }
    var action: () -> Void = {}

    var body: some View {
        Group {
            if options.isEmpty {
                Button(action: action) { icon }
            } else {
                Menu {
                    ForEach(options, id: \.self) { type in
                        Button { onPick(type) } label: {
                            Image(systemName: type.editorIcon)
                            Text(type.label)
                            Text(type.editorDescription)
                        }
                    }
                } label: {
                    icon
                }
                .menuOrder(.fixed)
            }
        }
        .accessibilityLabel(Text(title))
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .medium))
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .modifier(FloatingGlass())
    }
}

private struct FloatingGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(AppColors.primary).interactive(), in: .circle)
        } else {
            content
                .foregroundStyle(AppColors.primary)
                .background(.regularMaterial, in: Circle())
                .overlay { Circle().stroke(.separator, lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }
}
