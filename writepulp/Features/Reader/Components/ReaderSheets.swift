//
//  ReaderSheets.swift
//  writepulp
//

import SwiftUI

struct ReaderSettingsSheet: View {
    @Environment(ReaderPreferences.self) private var preferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("reader_theme") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(ReaderTheme.all) { theme in themeCell(theme) }
                        }
                    }
                    Divider()
                    section("reader_font") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(ReaderFont.all) { font in fontCell(font) }
                        }
                    }
                    Divider()
                    stepper(
                        "reader_font_size",
                        value: "\(preferences.fontSize)",
                        canDecrease: preferences.fontSize > 12,
                        canIncrease: preferences.fontSize < 28,
                        decrease: { preferences.setFontSize(preferences.fontSize - 1) },
                        increase: { preferences.setFontSize(preferences.fontSize + 1) }
                    ) {
                        Slider(
                            value: Binding(
                                get: { Double(preferences.fontSize) },
                                set: { preferences.setFontSize(Int($0.rounded())) }
                            ),
                            in: 12...28,
                            step: 1
                        )
                    }
                    stepper(
                        "reader_line_height",
                        value: String(format: "%.1f", preferences.lineHeight),
                        canDecrease: preferences.lineHeight > 1.45,
                        canIncrease: preferences.lineHeight < 2.15,
                        decrease: { setLineHeight(preferences.lineHeight - 0.1) },
                        increase: { setLineHeight(preferences.lineHeight + 0.1) }
                    ) {
                        Slider(
                            value: Binding(get: { preferences.lineHeight }, set: { setLineHeight($0) }),
                            in: 1.4...2.2,
                            step: 0.1
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("reader_settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppColors.primary)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func setLineHeight(_ value: Double) {
        preferences.setLineHeight(min(max((value * 10).rounded() / 10, 1.4), 2.2))
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .semibold))
            content()
        }
    }

    private func themeCell(_ theme: ReaderTheme) -> some View {
        let isSelected = theme.id == preferences.theme
        return Button { preferences.setTheme(theme.id) } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.background)
                    .overlay { Circle().stroke(theme.accent) }
                    .overlay {
                        Text(verbatim: "Aa")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.text)
                    }
                    .frame(width: 32, height: 32)
                Text(theme.name)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(AppColors.onSurface)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primary : AppColors.outline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fontCell(_ font: ReaderFont) -> some View {
        let isSelected = font.id == preferences.font
        return Button { preferences.setFont(font.id) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(font.name).font(font.font(size: 15, weight: .medium))
                Text(verbatim: "Aa Bb Cc").font(font.font(size: 12))
            }
            .foregroundStyle(AppColors.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primary : AppColors.outline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stepper<Slider: View>(
        _ title: LocalizedStringKey,
        value: String,
        canDecrease: Bool,
        canIncrease: Bool,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void,
        @ViewBuilder slider: () -> Slider
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: decrease) { Image(systemName: "minus").frame(width: 36, height: 36) }
                    .disabled(!canDecrease)
                    .accessibilityLabel(Text("reader_decrease"))
                Text(verbatim: value)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .frame(minWidth: 32)
                Button(action: increase) { Image(systemName: "plus").frame(width: 36, height: 36) }
                    .disabled(!canIncrease)
                    .accessibilityLabel(Text("reader_increase"))
            }
            slider()
        }
    }
}

/// Chapters (or magazine pages); locked ones are shown but can't be opened.
@MainActor
struct ReaderTocSheet: View {
    let chapters: [ReaderChapterSummary]
    let currentId: String?
    let canOpen: @MainActor (ReaderChapterSummary) -> Bool
    let onSelect: @MainActor (ReaderChapterSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(chapters) { chapter in
                    row(chapter)
                }
                .listStyle(.plain)
                .onAppear {
                    if let currentId { proxy.scrollTo(currentId, anchor: .center) }
                }
            }
            .navigationTitle("reader_chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .tint(AppColors.onSurface)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ chapter: ReaderChapterSummary) -> some View {
        let isCurrent = chapter.id == currentId
        let isOpen = canOpen(chapter)
        return Button {
            onSelect(chapter)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.system(size: 15, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? AppColors.primary : (isOpen ? AppColors.onSurface : AppColors.onSurfaceVariant))
                    if let subtitle = chapter.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if !isOpen {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .accessibilityLabel(Text("reader_chapter_locked"))
                } else if let progress = chapter.userProgress, progress > 0 {
                    ProgressRing(progress: progress / 100)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!isOpen)
        .id(chapter.id)
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.outline, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel(Text(verbatim: "\(Int(progress * 100))%"))
    }
}

/// Shown instead of a chapter the reader has no access to.
struct ReaderLockedView: View {
    let theme: ReaderTheme
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.text)
            Text("reader_locked_title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text)
            Text("reader_locked_message")
                .font(.system(size: 14))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Button(action: onBack) {
                Text("reader_locked_back_to_details")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error with retry, in the reading theme's colors.
struct ReaderErrorView: View {
    let message: String
    let theme: ReaderTheme
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(theme.secondaryText)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
            Button("retry", action: retry)
                .font(.system(size: 15, weight: .semibold))
                .tint(AppColors.primary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder lines while a chapter loads.
struct ReaderSkeleton: View {
    let theme: ReaderTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<14, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.text.opacity(0.08))
                    .frame(height: index == 0 ? 26 : 13)
                    .frame(maxWidth: index == 0 ? 220 : (index % 4 == 3 ? 180 : .infinity), alignment: .leading)
                    .padding(.bottom, index == 0 ? 12 : 0)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .shimmering()
    }
}
