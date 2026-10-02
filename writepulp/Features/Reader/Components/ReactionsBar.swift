//
//  ReactionsBar.swift
//  writepulp
//

import SwiftUI

@MainActor
struct ReactionsBar: View {
    let model: ReactionsViewModel
    let theme: ReaderTheme
    /// Runs the action when signed in, otherwise asks the user to sign in.
    let requireSignIn: (@escaping () -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(theme.text.opacity(0.12))
            Text("reactions_title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text.opacity(0.75))
            HStack(spacing: 8) {
                ForEach(ReactionType.allCases, id: \.self) { type in
                    button(type)
                }
            }
            if model.total > 0 {
                Text("reactions_total".localized(model.total))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.opacity(0.6))
            }
            Divider().overlay(theme.text.opacity(0.12))
        }
        .task { await model.loadIfNeeded() }
    }

    private func button(_ type: ReactionType) -> some View {
        let isActive = model.mine == type
        let count = model.counts[type] ?? 0
        let foreground = isActive ? type.color : theme.text.opacity(0.55)
        return Button {
            requireSignIn { Task { await model.pick(type) } }
        } label: {
            VStack(spacing: 4) {
                Text(verbatim: type.emoji)
                    .font(.system(size: 22))
                    .grayscale(isActive ? 0 : 0.6)
                Text(verbatim: count > 0 ? "\(count)" : "·")
                    .font(.system(size: 12, weight: .bold))
                Text(type.title)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? type.color.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? type.color : theme.text.opacity(0.18), lineWidth: 1.5)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isActive)
        .accessibilityLabel(Text(type.title))
        .accessibilityValue(Text(verbatim: "\(count)"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private extension ReactionType {
    var emoji: String {
        switch self {
        case .like: "👍"
        case .love: "❤️"
        case .laugh: "😂"
        case .angry: "😠"
        case .sad: "😢"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .like: "reactions_like"
        case .love: "reactions_love"
        case .laugh: "reactions_laugh"
        case .angry: "reactions_angry"
        case .sad: "reactions_sad"
        }
    }

    var color: Color {
        switch self {
        case .like: Color(hex: 0x60809E)
        case .love: Color(hex: 0xE85D75)
        case .laugh: Color(hex: 0xD4920A)
        case .angry: Color(hex: 0xC45C26)
        case .sad: Color(hex: 0x5B7C9D)
        }
    }
}
