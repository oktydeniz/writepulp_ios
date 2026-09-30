//
//  InspirationBox.swift
//  writepulp
//

import SwiftUI

/// Daily writing prompt, local to the device (Resources/Inspiration/inspiration_<lang>.json).
struct InspirationItem: Decodable {
    let title: String
    let body: String
    let tag: String

    static let total = 150

    static func item(at index: Int) -> InspirationItem? {
        let pool = AppPreferences.currentLanguageCode == "tr" ? poolTR : poolEN
        return pool.indices.contains(index) ? pool[index] : pool.first
    }

    private static let poolEN = load("inspiration_en")
    private static let poolTR = load("inspiration_tr")

    private static func load(_ name: String) -> [InspirationItem] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([InspirationItem].self, from: data)) ?? []
    }
}

/// Warm amber card, deliberately off the blue theme (same palette as web/Android).
struct InspirationBoxCard: View {
    let index: Int
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    private static let gold = Color(hex: 0xE8B84B)
    private static let goldDark = Color(hex: 0xC99A2E)

    var body: some View {
        if let item = InspirationItem.item(at: index) {
            card(item)
        }
    }

    private func card(_ item: InspirationItem) -> some View {
        let isDark = colorScheme == .dark
        let accent = isDark ? Self.gold : Self.goldDark
        let short = shortBody(item.body)

        return HStack(spacing: 0) {
            Self.gold.frame(width: 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                            .frame(width: 28, height: 28)
                            .background(Self.gold.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 0) {
                            Text("inspiration_box_label")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accent)
                            Text("inspiration_box_counter".localized(index + 1, InspirationItem.total))
                                .font(.system(size: 11))
                                .foregroundStyle(accent.opacity(0.65))
                        }
                    }
                    Spacer()
                    Text(item.tag)
                        .font(.system(size: 11))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Self.gold.opacity(isDark ? 0.12 : 0.15), in: Capsule())
                        .overlay { Capsule().stroke(Self.gold.opacity(isDark ? 0.2 : 0.25)) }
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.55))
                            .frame(width: 26, height: 26)
                    }
                    .accessibilityLabel(Text("close"))
                }
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDark ? Color(hex: 0xEAECEF) : Color(hex: 0x1A2332))
                    .padding(.top, 10)
                Text(isExpanded ? item.body : short)
                    .font(.system(size: 14))
                    .foregroundStyle(isDark ? Color(hex: 0xB8C0CA) : Color(hex: 0x3D4F61))
                    .padding(.top, 6)
                if item.body.count > short.count {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "inspiration_box_read_less" : "inspiration_box_read_more")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(
            LinearGradient(
                colors: isDark
                    ? [Self.gold.opacity(0.14), Self.gold.opacity(0.05)]
                    : [Color(hex: 0xFDF3DC), Color(hex: 0xFFF9EC)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Self.gold.opacity(isDark ? 0.3 : 0.35)) }
    }

    /// First sentence, or the first 120 characters, whichever is shorter.
    private func shortBody(_ body: String) -> String {
        if let dot = body.range(of: ". "), body.distance(from: body.startIndex, to: dot.lowerBound) < 120 {
            return String(body[..<dot.lowerBound]) + "."
        }
        return String(body.prefix(120)).trimmingCharacters(in: .whitespaces)
    }
}
