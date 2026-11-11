//
//  ReaderScrollView.swift
//  writepulp
//

import SwiftUI
import Observation

/// Live scroll position of a reader page; only views that read it re-render while scrolling.
@Observable
final class ReaderScrollState {
    fileprivate(set) var offset: CGFloat = 0
    /// 0...1 of the scrollable distance.
    fileprivate(set) var fraction: Double = 0
    fileprivate var scrollToTopRequest = 0

    func scrollToTop() {
        scrollToTopRequest += 1
    }
}

/// Vertical reader scroll view: reports reading progress (0-100) and, once per `restoreKey`,
/// scrolls back to `initialProgress` before reporting anything.
///
/// Pages that put more than the text in the scroll (article header and footer, magazine hero)
/// mark the text with `.readerProgressText()`. Progress then counts the text only: the share of it
/// that has come above the bottom of the screen - 0 before it starts, 100 once its end is visible -
/// and restoring puts that point back at the bottom of the screen. Same rule as web
/// (utils/readingProgress.ts) and Android (ReaderTextBounds). Without a marked text (book chapters,
/// which are only text) it is the share of the scrollable distance, as before.
struct ReaderScrollView<Content: View>: View {
    let restoreKey: String
    let initialProgress: Double
    let state: ReaderScrollState
    let onProgress: (Double) -> Void
    @ViewBuilder let content: () -> Content

    @State private var layout = LayoutBox()
    /// Invisible scroll targets every `markSpacing` points, so any position can be restored.
    @State private var markCount = 0
    /// The page fades in once its reading position is restored, instead of jumping there visibly.
    @State private var shownKey: String?

    private static var markSpacing: CGFloat { 120 }

    private static var space: String { "readerScroll" }
    private static var topId: String { "reader_top" }

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id(Self.topId)
                        content()
                    }
                    .onPreferenceChange(ReaderTextFrameKey.self) { frame in
                        layout.textFrame = frame
                    }
                    .opacity(shownKey == restoreKey || initialProgress <= 0 ? 1 : 0)
                    .background(alignment: .top) {
                        VStack(spacing: 0) {
                            ForEach(0..<markCount, id: \.self) { index in
                                Color.clear.frame(height: Self.markSpacing).id(Self.markId(index))
                            }
                        }
                    }
                    .background {
                        GeometryReader { geometry in
                            let frame = geometry.frame(in: .named(Self.space))
                            Color.clear
                                .onAppear { measured(frame, viewport: outer.size.height) }
                                .onChange(of: frame) { _, frame in measured(frame, viewport: outer.size.height) }
                        }
                    }
                }
                .coordinateSpace(name: Self.space)
                .onChange(of: state.scrollToTopRequest) {
                    withAnimation(.easeInOut) { proxy.scrollTo(Self.topId, anchor: .top) }
                }
                .task(id: restoreKey) {
                    await restore(proxy: proxy, viewport: outer.size.height)
                }
            }
        }
    }

    private func measured(_ frame: CGRect, viewport: CGFloat) {
        layout.contentHeight = frame.height
        layout.contentMinY = frame.minY
        let marks = Int((frame.height / Self.markSpacing).rounded(.down))
        if marks != markCount { markCount = marks }
        report(offset: -frame.minY, viewport: viewport)
    }

    private static func markId(_ index: Int) -> String { "reader_mark_\(index)" }

    private func report(offset: CGFloat, viewport: CGFloat) {
        let fraction: Double
        if let text = layout.textRange {
            fraction = min(max(Double((offset + viewport - text.top) / text.height), 0), 1)
        } else {
            let maxScroll = layout.contentHeight - viewport
            fraction = maxScroll > 1 ? min(max(Double(offset / maxScroll), 0), 1) : 1
        }
        state.offset = offset
        state.fraction = fraction
        guard layout.restoredKey == restoreKey, layout.contentHeight > 0 else { return }
        onProgress(fraction * 100)
    }

    private func restore(proxy: ScrollViewProxy, viewport: CGFloat) async {
        layout.restoredKey = nil
        proxy.scrollTo(Self.topId, anchor: .top)
        if initialProgress > 0 {
            // Wait for the blocks to lay out (images keep their placeholder height until loaded).
            var attempts = 0
            while attempts < 30, layout.contentHeight <= viewport {
                attempts += 1
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { return }
            let progress = CGFloat(initialProgress / 100)
            let target: CGFloat
            if let text = layout.textRange {
                target = min(max(0, text.top + progress * text.height - viewport), max(0, layout.contentHeight - viewport))
            } else {
                target = progress * max(0, layout.contentHeight - viewport)
            }
            let index = min(Int(target / Self.markSpacing), markCount - 1)
            if index > 0 { proxy.scrollTo(Self.markId(index), anchor: .top) }
            try? await Task.sleep(for: .milliseconds(100))
        }
        if Task.isCancelled { return }
        layout.restoredKey = restoreKey
        withAnimation(.easeOut(duration: 0.2)) { shownKey = restoreKey }
    }
}

/// Measurements that change on layout; kept out of SwiftUI state so scrolling doesn't re-render the page.
private final class LayoutBox {
    var contentHeight: CGFloat = 0
    /// Content top in the scroll's coordinate space (moves with scrolling, like the text frame).
    var contentMinY: CGFloat = 0
    /// Frame of the `.readerProgressText()` view in the same space, if the page marks one.
    var textFrame: CGRect?
    var restoredKey: String?

    /// The marked text's top (relative to the content, so independent of scrolling) and height.
    var textRange: (top: CGFloat, height: CGFloat)? {
        guard let frame = textFrame, frame.height > 0 else { return nil }
        return (frame.minY - contentMinY, frame.height)
    }
}

private struct ReaderTextFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Marks the text of a reader page so ReaderScrollView measures progress over it alone.
    func readerProgressText() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: ReaderTextFrameKey.self, value: geometry.frame(in: .named("readerScroll")))
            }
        }
    }
}
