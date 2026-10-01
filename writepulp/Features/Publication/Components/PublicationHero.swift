//
//  PublicationHero.swift
//  writepulp
//

import SwiftUI

/// Type-aware header. Books and magazines show a physical-looking cover on a blurred backdrop;
/// articles and scripts get a wide editorial image with the title laid over it.
struct PublicationHero: View {
    let publication: PublicationDetail
    let onAuthorTap: () -> Void
    let onCoverTap: () -> Void

    var body: some View {
        if publication.isCoverWide {
            EditorialHero(publication: publication, onAuthorTap: onAuthorTap, onCoverTap: onCoverTap)
        } else {
            CoverHero(publication: publication, onAuthorTap: onAuthorTap, onCoverTap: onCoverTap)
        }
    }
}

// MARK: - Book / magazine

private struct CoverHero: View {
    let publication: PublicationDetail
    let onAuthorTap: () -> Void
    let onCoverTap: () -> Void

    private var isMagazine: Bool { publication.type == .magazine }
    private var coverSize: CGSize { isMagazine ? CGSize(width: 156, height: 208) : CGSize(width: 136, height: 204) }

    var body: some View {
        VStack(spacing: 14) {
            cover
                .padding(.top, 24)

            HeroTypeRow(publication: publication)

            Text(publication.title)
                .font(.system(size: 26, weight: .heavy, design: isMagazine ? .default : .serif))
                .foregroundStyle(AppColors.onBackground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            AuthorChip(author: publication.author, action: onAuthorTap)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .background(alignment: .top) { backdrop }
    }

    private var cover: some View {
        Button(action: onCoverTap) {
            CoverImage(path: publication.coverImg, title: publication.title)
                .frame(width: coverSize.width, height: coverSize.height)
                .overlay(alignment: .leading) {
                    if !isMagazine {
                        // Book spine.
                        LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 10)
                    }
                }
                .overlay {
                    if isMagazine {
                        // Glossy paper.
                        LinearGradient(colors: [.white.opacity(0.28), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: isMagazine ? 6 : 3,
                    bottomLeadingRadius: isMagazine ? 6 : 3,
                    bottomTrailingRadius: isMagazine ? 6 : 10,
                    topTrailingRadius: isMagazine ? 6 : 10
                ))
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
                .rotation3DEffect(.degrees(isMagazine ? 0 : 4), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(publication.coverImg?.isEmpty ?? true)
    }

    private var backdrop: some View {
        CoverImage(path: publication.coverImg, title: publication.title)
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .blur(radius: 30)
            .opacity(0.6)
            .overlay {
                LinearGradient(colors: [.clear, AppColors.background], startPoint: .center, endPoint: .bottom)
            }
            .clipped()
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
    }
}

// MARK: - Article / script

private struct EditorialHero: View {
    let publication: PublicationDetail
    let onAuthorTap: () -> Void
    let onCoverTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onCoverTap) {
                CoverImage(path: publication.coverImg, title: publication.title)
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 10) {
                            HeroTypeRow(publication: publication, onImage: true)
                            Text(publication.title)
                                .font(.system(size: 28, weight: .heavy, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .shadow(color: .black.opacity(0.4), radius: 6)
                        }
                        .padding(20)
                    }
            }
            .buttonStyle(.plain)
            .disabled(publication.coverImg?.isEmpty ?? true)
            .ignoresSafeArea(edges: .top)

            AuthorChip(author: publication.author, action: onAuthorTap)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Shared pieces

/// Type pill, badges and the AI marker.
private struct HeroTypeRow: View {
    let publication: PublicationDetail
    var onImage = false

    var body: some View {
        HStack(spacing: 6) {
            pill(Text(publication.type.label), background: AppColors.primary, foreground: .white)
            if publication.isSupportedWithAI {
                pill(Text("badge_ai"), background: Color(hex: 0x7C5CBF), foreground: .white)
            }
            ForEach(Array((publication.badges ?? []).prefix(2).enumerated()), id: \.offset) { _, badge in
                if let title = badge.title {
                    pill(
                        Text(title),
                        background: onImage ? AppPalette.goldAccent : AppPalette.goldAccent.opacity(0.22),
                        foreground: onImage ? .black : Color(hex: 0x8A5A00)
                    )
                }
            }
        }
    }

    private func pill(_ text: Text, background: Color, foreground: Color) -> some View {
        text
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }
}

private struct AuthorChip: View {
    let author: PublicationDetail.Author
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Avatar(imagePath: author.avatarImg, name: author.fullName, size: 28)
                Text(author.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .background(AppColors.surface, in: Capsule())
            .overlay { Capsule().stroke(AppColors.outline) }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Cover with a title-colored gradient when there is no image.
struct CoverImage: View {
    let path: String?
    let title: String

    var body: some View {
        Color.clear.overlay {
            AsyncImage(url: AppEnvironment.imageURL(path)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [PlaceholderColor.color(for: title), PlaceholderColor.color(for: title + "x")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Text(title.prefix(1).uppercased())
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .clipped()
    }
}
