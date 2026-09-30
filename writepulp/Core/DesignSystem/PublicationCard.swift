//
//  PublicationCard.swift
//  writepulp
//

import SwiftUI

/// What a publication card shows; features map their own models into this.
struct PublicationCardContent: Identifiable, Hashable {
    let id: String
    let title: String
    let coverImg: String?
    let type: PublicationType
    let authorName: String
    let rating: Double
    let views: Int
    /// Only books show it, and only when the source provides it.
    var sectionCount: Int?
    let readTimeMinutes: Int?
}

/// Cover + type badge, author, title and meta row (rating, views, chapters, read time).
struct PublicationCard: View {
    let content: PublicationCardContent
    var coverHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(content.authorName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
                Text(content.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                meta
            }
            .padding(12)
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cover: some View {
        Color.clear
            .frame(height: coverHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                AsyncImage(url: AppEnvironment.imageURL(content.coverImg)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [
                                PlaceholderColor.color(for: content.title),
                                PlaceholderColor.color(for: content.title + "x"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Text(content.title.prefix(1).uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(content.type.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.primaryContainer, in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
    }

    private var meta: some View {
        HStack(spacing: 12) {
            MetaLabel(systemImage: "star.fill", text: String(format: "%.1f", content.rating), tint: Color(hex: 0xFFB800))
            MetaLabel(systemImage: "eye", text: Formatters.compactCount(content.views))
            if content.type == .book, let sections = content.sectionCount {
                MetaLabel(systemImage: "book", text: "\(sections)")
            }
            if let readTime = Formatters.readTime(minutes: content.readTimeMinutes) {
                MetaLabel(systemImage: "clock", text: readTime)
            }
        }
    }
}

private struct MetaLabel: View {
    let systemImage: String
    let text: String
    var tint: Color = AppColors.onSurfaceVariant

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
    }
}
