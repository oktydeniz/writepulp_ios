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

/// A round "+" button for the bottom-right corner. With `options` it opens a speed dial of
/// work types; without, it runs `action` straight away.
@MainActor
struct FloatingCreateButton: View {
    var title: LocalizedStringKey = "editor_new_work"
    var systemImage = "plus"
    var options: [PublicationType] = []
    var onPick: (PublicationType) -> Void = { _ in }
    var action: () -> Void = {}

    @State private var isOpen = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { toggle() }
                    .transition(.opacity)
            }
            VStack(alignment: .trailing, spacing: 12) {
                if isOpen {
                    ForEach(Array(options.enumerated()), id: \.element) { index, type in
                        option(type)
                            .transition(.move(edge: .bottom).combined(with: .opacity)
                                .animation(.spring(duration: 0.3).delay(Double(options.count - index) * 0.03)))
                    }
                }
                mainButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
    }

    private var mainButton: some View {
        Button {
            if options.isEmpty { action() } else { toggle() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColors.onPrimary)
                .rotationEffect(.degrees(isOpen ? 45 : 0))
                .frame(width: 56, height: 56)
                .background(AppColors.primary, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(title))
    }

    private func option(_ type: PublicationType) -> some View {
        Button {
            toggle()
            onPick(type)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(type.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.onSurface)
                    Text(type.editorDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                Image(systemName: type.editorIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(type.editorTint, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(AppColors.surface, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func toggle() {
        withAnimation(.spring(duration: 0.3)) { isOpen.toggle() }
    }
}
