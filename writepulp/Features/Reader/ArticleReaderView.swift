//
//  ArticleReaderView.swift
//  writepulp
//

import SwiftUI

/// Single-page reader for articles and scripts, with reactions and reviews at the end.
@MainActor
struct ArticleReaderView: View {
    let onOpen: (MainRoute) -> Void
    let onSignIn: () -> Void

    @Environment(ReaderPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    @State private var model: ArticleReaderViewModel
    @State private var scroll = ReaderScrollState()
    @State private var isShowingSettings = false
    @State private var signInMessage: LocalizedStringKey?

    init(publicationId: String, service: ReaderService, onOpen: @escaping (MainRoute) -> Void, onSignIn: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onSignIn = onSignIn
        _model = State(initialValue: ArticleReaderViewModel(publicationId: publicationId, service: service))
    }

    var body: some View {
        let style = preferences.style(colorScheme: colorScheme)
        content(style)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                ReaderProgressLine(state: scroll, track: style.theme.text.opacity(0.08))
            }
            .overlay(alignment: .bottomTrailing) {
                BackToTopButton(state: scroll, theme: style.theme)
            }
            .readerChrome(theme: style.theme, pause: model.pauseSession, resume: model.resumeSession)
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingSettings) { ReaderSettingsSheet() }
            .toast($model.toastMessage)
            .alert("sign_in", isPresented: Binding(
                get: { signInMessage != nil },
                set: { if !$0 { signInMessage = nil } }
            )) {
                Button("cancel", role: .cancel) {}
                Button("sign_in", action: onSignIn)
            } message: {
                if let signInMessage { Text(signInMessage) }
            }
            .task { await model.start() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { isShowingSettings = true } label: { ReaderToolbarIcon(systemName: "textformat.size") }
                .accessibilityLabel(Text("article_reading_settings"))
            if let article = model.article {
                if !article.isOwner {
                    Button { toggleBookmark() } label: {
                        ReaderToolbarIcon(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(Text("article_save_article"))
                }
                ShareLink(item: AppLinks.publication(article.publication.uuid), subject: Text(article.title)) {
                    ReaderToolbarIcon(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("article_share"))
            }
        }
    }

    @ViewBuilder
    private func content(_ style: ReaderStyle) -> some View {
        if let article = model.article {
            ReaderScrollView(
                restoreKey: article.id,
                initialProgress: article.userProgress ?? 0,
                state: scroll,
                onProgress: model.recordProgress
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ArticleHeader(article: article, theme: style.theme, isSignedIn: model.isSignedIn, onOpen: onOpen)
                    ReaderBlocks(blocks: model.document.blocks, style: style)
                        .padding(.top, 20)
                    footer(article, theme: style.theme)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
        } else if let error = model.errorMessage, !model.isLoading {
            ReaderErrorView(message: error, theme: style.theme) { Task { await model.load() } }
        } else {
            ReaderSkeleton(theme: style.theme)
        }
    }

    @ViewBuilder
    private func footer(_ article: ReaderArticle, theme: ReaderTheme) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if let reactions = model.reactions {
                ReactionsBar(model: reactions, theme: theme) { action in
                    requireSignIn("article_login_to_save", action)
                }
            }

            HStack(spacing: 12) {
                if !article.isOwner {
                    outlinedButton(
                        model.isSaved ? "article_saved" : "article_save",
                        systemImage: model.isSaved ? "bookmark.fill" : "bookmark",
                        theme: theme
                    ) { toggleBookmark() }
                }
                ShareLink(item: AppLinks.publication(article.publication.uuid), subject: Text(article.title)) {
                    outlinedLabel("article_share", systemImage: "square.and.arrow.up", theme: theme)
                }
            }

            if !article.publication.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(article.publication.tags, id: \.self) { tag in
                        Text(verbatim: "#\(tag)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            ArticleAuthorCard(author: article.publication.author, theme: theme) {
                onOpen(.profile(userId: article.publication.author.uuid))
            }

            if let reviews = model.reviews {
                ReviewsSection(
                    model: reviews,
                    reviewAverage: reviews.averageRating,
                    reviewCount: reviews.reviews.items.count,
                    isOwner: article.isOwner,
                    onSignIn: onSignIn,
                    onOpenProfile: { onOpen(.profile(userId: $0)) }
                )
                .environment(\.reviewsPalette, theme.reviewsPalette)
            }
        }
        .padding(.top, 24)
    }

    private func outlinedButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        theme: ReaderTheme,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { outlinedLabel(title, systemImage: systemImage, theme: theme) }
            .buttonStyle(PressableButtonStyle())
    }

    private func outlinedLabel(_ title: LocalizedStringKey, systemImage: String, theme: ReaderTheme) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay { Capsule().stroke(theme.text.opacity(0.25)) }
            .contentShape(Capsule())
    }

    private func toggleBookmark() {
        requireSignIn("article_login_to_save") { Task { await model.toggleBookmark() } }
    }

    private func requireSignIn(_ message: LocalizedStringKey, _ action: () -> Void) {
        if model.isSignedIn {
            action()
        } else {
            signInMessage = message
        }
    }
}

private struct ArticleHeader: View {
    let article: ReaderArticle
    let theme: ReaderTheme
    let isSignedIn: Bool
    let onOpen: (MainRoute) -> Void

    @Environment(NetworkMonitor.self) private var network

    private var publication: ReaderPublicationSummary { article.publication }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8) {
                ForEach(publication.categories, id: \.self) { category in
                    Button {
                        onOpen(.categoryExplore(slug: category.slug, title: category.name))
                    } label: {
                        Text(category.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.accent.opacity(0.15), in: Capsule())
                            .overlay { Capsule().stroke(theme.accent) }
                    }
                    .buttonStyle(.plain)
                }
                if publication.estimateReadTime > 0 {
                    meta("article_min_read".localized(publication.estimateReadTime), systemImage: "clock")
                }
                meta(viewCount(publication.totalViews), systemImage: "eye")
            }

            Text(article.title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(theme.text)
                .padding(.top, 16)

            if let summary = publication.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 17))
                    .foregroundStyle(theme.text.opacity(0.85))
                    .padding(.top, 10)
            }

            authorRow.padding(.top, 24)
            hero.padding(.top, 24)
        }
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            Button { onOpen(.profile(userId: publication.author.uuid)) } label: {
                Avatar(imagePath: publication.author.avatarImg, name: publication.author.fullName, size: 40)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(publication.author.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let date = publication.publishDate {
                    Text(Formatters.mediumDate(date))
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            // Nothing is earned offline, including downloaded copies.
            if isSignedIn, article.earnsCoins, network.isOnline {
                Label("article_coins_while_reading", systemImage: "bitcoinsign.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
                    .labelStyle(CompactLabelStyle())
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        if let cover = publication.coverImg, !cover.isEmpty {
            Color.clear
                .frame(height: 220)
                .overlay {
                    AsyncImage(url: AppEnvironment.imageURL(cover)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            theme.accent.opacity(0.25)
                        }
                    }
                }
                .clipShape(shape)
        } else {
            theme.accent.opacity(0.25)
                .frame(height: 220)
                .overlay {
                    Text(String(article.title.prefix(1)).uppercased())
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundStyle(theme.text)
                }
                .clipShape(shape)
        }
    }

    private func meta(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(theme.secondaryText)
            .labelStyle(CompactLabelStyle())
            .padding(.vertical, 5)
    }

    private func viewCount(_ count: Int) -> String {
        switch count {
        case 1_000_000...: "article_views_m".localized(String(format: "%.1f", Double(count) / 1_000_000))
        case 1_000...: "article_views_k".localized(String(format: "%.1f", Double(count) / 1_000))
        default: "article_views".localized(count)
        }
    }
}

private struct ArticleAuthorCard: View {
    let author: ReaderAuthor
    let theme: ReaderTheme
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Avatar(imagePath: author.avatarImg, name: author.fullName, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("article_written_by")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text.opacity(0.6))
                    Text(author.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.text)
                    if let handle = author.handle, !handle.isEmpty {
                        Text(verbatim: "@\(handle)")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            Group {
                if let about = author.about?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
                    Text(about)
                } else {
                    Text("article_author_bio_fallback")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(theme.text.opacity(0.85))
            .lineLimit(3)

            if author.followersCount != nil || author.worksCount != nil {
                HStack(spacing: 6) {
                    if let followers = author.followersCount {
                        Text("article_followers_count".localized(Formatters.compactCount(followers)))
                    }
                    if author.followersCount != nil, author.worksCount != nil {
                        Text(verbatim: "·")
                    }
                    if let works = author.worksCount {
                        Text("article_works_count".localized(works))
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryText)
            }

            Button(action: onOpenProfile) {
                Text("article_view_profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}

/// Appears once the page has been scrolled a bit.
private struct BackToTopButton: View {
    let state: ReaderScrollState
    let theme: ReaderTheme

    var body: some View {
        let isVisible = state.offset > 600
        ZStack {
            if isVisible { button }
        }
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }

    private var button: some View {
        Button { state.scrollToTop() } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(AppColors.primary, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(20)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel(Text("article_back_to_top"))
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
