//
//  BookReaderView.swift
//  writepulp
//

import SwiftUI

/// Chapter reader for books, open books and multi-chapter scripts.
@MainActor
struct BookReaderView: View {
    @Environment(ReaderPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var model: BookReaderViewModel
    @State private var scroll = ReaderScrollState()
    @State private var isShowingToc = false
    @State private var isShowingSettings = false

    init(publicationId: String, chapterId: String?, service: ReaderService) {
        _model = State(initialValue: BookReaderViewModel(publicationId: publicationId, chapterId: chapterId, service: service))
    }

    var body: some View {
        let style = preferences.style(colorScheme: colorScheme)
        content(style)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.chapter != nil { bottomBar(style.theme) }
            }
            .readerChrome(theme: style.theme, pause: model.pauseSession, resume: model.resumeSession)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(model.chapter?.title ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(style.theme.text)
                        .lineLimit(1)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { isShowingToc = true } label: { ReaderToolbarIcon(systemName: "list.bullet") }
                        .accessibilityLabel(Text("reader_chapters"))
                        .disabled(model.chapters.isEmpty)
                    Button { isShowingSettings = true } label: { ReaderToolbarIcon(systemName: "textformat.size") }
                        .accessibilityLabel(Text("reader_settings"))
                }
            }
            .sheet(isPresented: $isShowingToc) {
                ReaderTocSheet(
                    chapters: model.chapters,
                    currentId: model.chapter?.id,
                    canOpen: model.canOpen,
                    onSelect: model.select
                )
            }
            .sheet(isPresented: $isShowingSettings) { ReaderSettingsSheet() }
            .task { await model.start() }
    }

    @ViewBuilder
    private func content(_ style: ReaderStyle) -> some View {
        if let chapter = model.chapter {
            if !chapter.isAccessible {
                ReaderLockedView(theme: style.theme) { dismiss() }
            } else {
                ReaderScrollView(
                    restoreKey: chapter.id,
                    initialProgress: chapter.userProgress ?? 0,
                    state: scroll,
                    onProgress: model.recordProgress
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        chapterHeader(chapter, theme: style.theme)
                        ReaderBlocks(blocks: model.document.blocks, style: style)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .overlay(alignment: .top) {
                    if model.isLoading { ProgressView().padding(.top, 8) }
                }
            }
        } else if let error = model.errorMessage, !model.isLoading {
            ReaderErrorView(message: error, theme: style.theme) { Task { await model.retry() } }
        } else {
            ReaderSkeleton(theme: style.theme)
        }
    }

    private func chapterHeader(_ chapter: ReaderChapter, theme: ReaderTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(chapter.title)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(theme.text)
            if let subtitle = chapter.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }

    private func bottomBar(_ theme: ReaderTheme) -> some View {
        VStack(spacing: 0) {
            ReaderProgressLine(state: scroll, track: theme.text.opacity(0.08))

            HStack {
                navButton("reader_previous_chapter", systemImage: "chevron.left", enabled: model.hasPrevious, leading: true) {
                    model.goToPrevious()
                }
                Spacer()
                if !model.chapters.isEmpty {
                    Text(verbatim: "\(model.chapterNumber) / \(model.chapters.count)")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                navButton("reader_next_chapter", systemImage: "chevron.right", enabled: model.hasNext, leading: false) {
                    model.goToNext()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(theme.background)
    }

    private func navButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        enabled: Bool,
        leading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if leading { Image(systemName: systemImage) }
                Text(title)
                if !leading { Image(systemName: systemImage) }
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}
