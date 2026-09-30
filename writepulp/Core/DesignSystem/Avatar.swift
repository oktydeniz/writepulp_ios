//
//  Avatar.swift
//  writepulp
//

import SwiftUI

/// Stable accent color for a title or name, used where there is no image.
enum PlaceholderColor {
    private static let palette: [Color] = [
        Color(hex: 0x4A6B88), Color(hex: 0x60809E), Color(hex: 0x7A9BB8), Color(hex: 0x354F65),
        Color(hex: 0x3DAA72), Color(hex: 0xE8973B), Color(hex: 0xD95050), Color(hex: 0x7C5CBF),
    ]

    static func color(for text: String) -> Color {
        var hash: Int32 = 0
        // Same 32-bit rolling hash over UTF-16 units as Android, so colors match across platforms.
        for unit in text.utf16 {
            hash = Int32(truncatingIfNeeded: Int64(unit) + ((Int64(hash) << 5) - Int64(hash)))
        }
        return palette[Int(hash.magnitude) % palette.count]
    }
}

/// Round image with the first letter of `name` on a colored circle as fallback.
struct Avatar: View {
    let imagePath: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: AppEnvironment.imageURL(imagePath)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    PlaceholderColor.color(for: name)
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
