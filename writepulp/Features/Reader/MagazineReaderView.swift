//
//  MagazineReaderView.swift
//  writepulp
//

import SwiftUI

/// Magazine issue: swipe between pages, each with a full-bleed cover that fades as you read.
@MainActor
struct MagazineReaderView: View {
    @Environment(ReaderPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var model: MagazineReaderViewModel
    @State private var isShowingToc = false
    @State private var isShowingSettings = false

    init(publicationId: String, chapterId: String?, service: ReaderService) {
        _model = State(initialValue: MagazineReaderViewModel(publicationId: publicationId, chapterId: chapterId, service: service))
    }

    var body: some View {
        let style = preferences.style(colorScheme: colorScheme)
        content(style)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .readerChrome(theme: style.theme, pause: model.pauseSession, resume: model.resumeSession)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !model.chapters.isEmpty {
                        Text("reader_page_progress".localized(model.currentIndex + 1, model.chapters.count))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(style.theme.text)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { isShowingSettings = true } label: { ReaderToolbarIcon(systemName: "textformat.size") }
                        .accessibilityLabel(Text("reader_settings"))
                    Button { isShowingToc = true } label: { ReaderToolbarIcon(systemName: "list.bullet") }
                        .accessibilityLabel(Text("reader_chapters"))
                        .disabled(model.chapters.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingToc) {
                ReaderTocSheet(
                    chapters: model.chapters,
                    currentId: model.currentSummary?.id,
                    canOpen: model.canOpen,
                    onSelect: { summary in withAnimation { model.select(summary) } }
                )
            }
            .sheet(isPresented: $isShowingSettings) { ReaderSettingsSheet() }
            .task { await model.start() }
    }

    @ViewBuilder
    private func content(_ style: ReaderStyle) -> some View {
        if !model.chapters.isEmpty {
            TabView(selection: $model.currentIndex) {
                ForEach(Array(model.chapters.enumerated()), id: \.element.id) { index, summary in
                    page(summary, index: index, style: style)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
        } else if let error = model.errorMessage, !model.isLoading {
            ReaderErrorView(message: error, theme: style.theme) { Task { await model.load() } }
        } else if model.chaptersList != nil {
            EmptyStateView(systemImage: "doc.text", title: "no_results_found")
        } else {
            ReaderSkeleton(theme: style.theme)
        }
    }

    @ViewBuilder
    private func page(_ summary: ReaderChapterSummary, index: Int, style: ReaderStyle) -> some View {
        Group {
            if !model.canOpen(summary) || model.pages[summary.id]?.content.isAccessible == false {
                ReaderLockedView(theme: style.theme) { dismiss() }
            } else if let loaded = model.pages[summary.id] {
                MagazinePageView(
                    page: loaded.content,
                    document: loaded.document,
                    index: index,
                    chapters: model.chapters,
                    style: style,
                    onProgress: { model.recordProgress($0, pageId: summary.id) },
                    onGoTo: { target in withAnimation { model.goTo(target) } }
                )
            } else if model.failedPages.contains(summary.id) {
                ReaderErrorView(message: String(localized: "error_unknown"), theme: style.theme) {
                    Task { await model.loadPageIfNeeded(summary) }
                }
            } else {
                ReaderSkeleton(theme: style.theme)
            }
        }
        .task { await model.loadPageIfNeeded(summary) }
    }
}

private struct MagazinePageView: View {
    let page: ReaderChapter
    let document: EditorDocument
    let index: Int
    let chapters: [ReaderChapterSummary]
    let style: ReaderStyle
    let onProgress: (Double) -> Void
    let onGoTo: (Int) -> Void

    @State private var scroll = ReaderScrollState()

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.55, 280), 460)
            ReaderScrollView(
                restoreKey: page.id,
                initialProgress: page.userProgress ?? 0,
                state: scroll,
                onProgress: onProgress
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    MagazineHero(
                        page: page,
                        readMinutes: max(1, Int((Double(document.blocks.count) * 0.4).rounded())),
                        index: index,
                        total: chapters.count,
                        height: heroHeight,
                        scroll: scroll
                    )
                    VStack(alignment: .leading, spacing: 20) {
                        ReaderBlocks(blocks: document.blocks, style: style)
                        pageNavigation
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var pageNavigation: some View {
        HStack(alignment: .center, spacing: 4) {
            navButton(target: index - 1, label: "reader_previous_chapter", systemImage: "arrow.left", leading: true)
            PageDots(total: chapters.count, current: index, onGoTo: onGoTo)
                .frame(maxWidth: .infinity)
            navButton(target: index + 1, label: "reader_next_chapter", systemImage: "arrow.right", leading: false)
        }
        .foregroundStyle(style.theme.text)
    }

    private func navButton(target: Int, label: LocalizedStringKey, systemImage: String, leading: Bool) -> some View {
        let isEnabled = chapters.indices.contains(target)
        return Button { onGoTo(target) } label: {
            HStack(spacing: 6) {
                if leading { Image(systemName: systemImage).font(.system(size: 13)) }
                VStack(alignment: leading ? .leading : .trailing, spacing: 1) {
                    Text(label).font(.system(size: 11))
                    if isEnabled {
                        Text(chapters[target].title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                if !leading { Image(systemName: systemImage).font(.system(size: 13)) }
            }
            .frame(maxWidth: 110, alignment: leading ? .leading : .trailing)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

private struct MagazineHero: View {
    let page: ReaderChapter
    let readMinutes: Int
    let index: Int
    let total: Int
    let height: CGFloat
    let scroll: ReaderScrollState

    var body: some View {
        // The cover fades and zooms slightly as the text scrolls over it.
        let progress = min(max(scroll.offset / (height * 0.85), 0), 1)
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 84, weight: .black))
                .foregroundStyle(.white.opacity(0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .accessibilityHidden(true)
            details
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .scaleEffect(1 + progress * 0.12)
        .opacity(1 - progress)
    }

    @ViewBuilder
    private var background: some View {
        if let cover = page.coverImg, !cover.isEmpty {
            let url = AppEnvironment.imageURL(cover)
            ZStack {
                // A blurred copy fills the frame; the real cover sits on top, uncropped.
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().blur(radius: 30)
                    } else {
                        fallbackColor
                    }
                }
                Color.black.opacity(0.3)
                AsyncImage(url: url) { phase in
                    phase.image?.resizable().scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            LinearGradient(colors: [fallbackColor, fallbackColor.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var fallbackColor: Color {
        Color(css: page.heroColor) ?? PlaceholderColor.color(for: page.title)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(page.pageType.titleKey.localized().uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
            Text(page.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            if let subtitle = page.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: 14) {
                Label("article_min_read".localized(readMinutes), systemImage: "clock")
                Text("reader_page_progress".localized(index + 1, total))
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct PageDots: View {
    let total: Int
    let current: Int
    let onGoTo: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { index in
                        Circle()
                            .fill(color(index))
                            .frame(width: index == current ? 9 : 7, height: index == current ? 9 : 7)
                            .frame(width: 14, height: 24)
                            .contentShape(Rectangle())
                            .onTapGesture { onGoTo(index) }
                            .id(index)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("reader_page_progress".localized(current + 1, total)))
    }

    private func color(_ index: Int) -> Color {
        if index == current { return AppColors.primary }
        if index < current { return AppColors.primary.opacity(0.4) }
        return Color.primary.opacity(0.15)
    }
}
