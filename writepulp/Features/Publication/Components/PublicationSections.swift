//
//  PublicationSections.swift
//  writepulp
//

import SwiftUI

/// Rating, reads, chapters and reading time.
struct PublicationStatsView: View {
    let publication: PublicationDetail

    var body: some View {
        HStack(spacing: 0) {
            stat(value: String(format: "%.1f", publication.reviewAverage ?? 0), label: "content_detail_stat_rating", systemImage: "star.fill", tint: Color(hex: 0xFFB800))
            divider
            stat(value: Formatters.compactCount(publication.totalClicked), label: "content_detail_stat_views", systemImage: "eye")
            if publication.hasChapterList {
                divider
                stat(value: "\(publication.sectionCount)", label: "content_detail_tab_chapters", systemImage: publication.type == .magazine ? "newspaper" : "book")
            }
            if let readTime = Formatters.readTime(minutes: publication.estimatedReadingTime) {
                divider
                stat(value: readTime, label: "reading_time", systemImage: "clock")
            }
        }
        .padding(.vertical, 14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline) }
    }

    private var divider: some View {
        Divider().frame(height: 32)
    }

    private func stat(value: String, label: LocalizedStringKey, systemImage: String, tint: Color = AppColors.primary) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                Text(verbatim: value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Summary, details, categories, tags, community and similar publications.
struct PublicationOverview: View {
    let publication: PublicationDetail
    let onOpen: (MainRoute) -> Void

    @State private var isSummaryExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            summary
            info
            if !publication.categories.isEmpty {
                section("categories") {
                    FlowLayout(spacing: 8) {
                        ForEach(publication.categories, id: \.slug) { category in
                            Button { onOpen(.categoryExplore(slug: category.slug, title: category.name)) } label: {
                                Text(category.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(AppColors.primary.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            if let tags = publication.tags, !tags.isEmpty {
                section("tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(verbatim: "#\(tag)")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                }
            }
            if publication.hasCommunity, let community = publication.community {
                communityCard(community)
            }
            if !publication.similarPublications.isEmpty {
                similar
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(publication.summary)
                .appTextStyle(.bodyLarge)
                .foregroundStyle(AppColors.onSurface)
                .lineLimit(isSummaryExpanded ? nil : 5)
            if publication.summary.count > 240 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isSummaryExpanded.toggle() }
                } label: {
                    Text(isSummaryExpanded ? "content_detail_show_less" : "content_detail_show_more")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var info: some View {
        section("content_detail_info") {
            VStack(spacing: 0) {
                if let lng = publication.lng, !lng.isEmpty {
                    infoRow("content_detail_language", value: Text(verbatim: ContentLanguage.displayName(for: lng.lowercased())))
                }
                if publication.hasChapterList, let isCompleted = publication.isCompleted {
                    infoRow("status", value: Text(isCompleted ? "status_completed" : "status_ongoing"))
                }
                if let copyright = publication.copyright {
                    infoRow("content_detail_license", value: Text(copyright.label))
                }
            }
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func infoRow(_ title: LocalizedStringKey, value: Text) -> some View {
        HStack {
            Text(title).foregroundStyle(AppColors.onSurfaceVariant)
            Spacer()
            value.foregroundStyle(AppColors.onSurface).fontWeight(.medium)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func communityCard(_ community: PublicationDetail.Community) -> some View {
        Button { onOpen(.community(id: community.uuid, name: community.name)) } label: {
            HStack(spacing: 12) {
                Avatar(imagePath: community.groupAvatar, name: community.name, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("content_detail_community_title")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                    Text(community.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                    Text("community_members_count".localized(community.memberCount))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(AppColors.primary)
            }
            .padding(14)
            .background(AppColors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityHint(Text("content_detail_go_to_community"))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var similar: some View {
        section("content_detail_similar_publications") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(publication.similarPublications) { item in
                        Button { onOpen(.publication(id: item.uuid)) } label: {
                            PublicationCard(content: item.cardContent, coverHeight: 140)
                                .frame(width: 160)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 1)
            }
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            content()
        }
    }
}

/// Chapter rows (magazine issues show each article with its cover).
struct PublicationChapterList: View {
    let publication: PublicationDetail
    let sections: [PublicationSection]
    let isLoadingMore: Bool
    let onOpen: (PublicationSection) -> Void
    let onLoadMore: () -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                let isLocked = !section.isFree && !publication.hasAccess
                Button { onOpen(section) } label: {
                    row(section, isLocked: isLocked)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isLocked)
                .onAppear {
                    if index >= sections.count - 3 { onLoadMore() }
                }
            }
            if isLoadingMore {
                ProgressView().padding(12)
            }
        }
    }

    private func row(_ section: PublicationSection, isLocked: Bool) -> some View {
        HStack(spacing: 12) {
            leading(section)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle = section.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                if let readTime = Formatters.readTime(minutes: section.estimatedReadTime) {
                    Label(readTime, systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                if let progress = section.userProgress, progress > 0 {
                    ProgressView(value: min(progress, 100), total: 100)
                        .tint(AppColors.primary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isLocked ? AppPalette.appLightGray : AppColors.primary)
                .accessibilityLabel(isLocked ? Text("content_detail_locked") : Text("content_detail_read_cta"))
        }
        .padding(12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
        .opacity(isLocked ? 0.65 : 1)
    }

    @ViewBuilder
    private func leading(_ section: PublicationSection) -> some View {
        if publication.type == .magazine {
            CoverImage(path: section.coverImg ?? publication.coverImg, title: section.title)
                .frame(width: 48, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottom) {
                    if let hex = section.heroColor.flatMap(Self.color(fromHex:)) {
                        hex.frame(height: 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Text(verbatim: "\(section.order)")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(AppColors.primary.opacity(0.12), in: Circle())
        }
    }

    private static func color(fromHex value: String) -> Color? {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let number = UInt32(hex, radix: 16) else { return nil }
        return Color(hex: number)
    }
}
