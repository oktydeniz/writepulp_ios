//
//  PocketView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct PocketView: View {
    let onOpen: (MainRoute) -> Void
    let onExplore: () -> Void

    @State private var model: PocketViewModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(service: PocketService, onOpen: @escaping (MainRoute) -> Void, onExplore: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onExplore = onExplore
        _model = State(initialValue: PocketViewModel(service: service))
    }

    var body: some View {
        Group {
            if model.hasLoaded {
                content
            } else if let error = model.errorMessage, !model.isLoading {
                ErrorStateView(message: error) { Task { await model.load() } }
            } else {
                PocketSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .toast($model.toastMessage)
        // Reloads on every visit so progress from reading elsewhere shows up.
        .task { await model.load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let lastRead = model.lastRead {
                    ContinueReadingCard(item: lastRead) { onOpen(.publication(id: lastRead.id)) }
                }

                tabs
                PocketSearchField(text: $model.query)

                if model.items.isEmpty {
                    PocketEmptyState(status: model.tab, onExplore: onExplore)
                } else {
                    grid
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await model.load() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("pocket_title")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.onBackground)
                Text("pocket_subtitle")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            Spacer()
            Button(action: onExplore) {
                HStack(spacing: 2) {
                    Text("pocket_discover_more")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryStatus.allCases, id: \.self) { status in
                    PocketTabChip(status: status, count: model.count(of: status), isSelected: model.tab == status) {
                        model.tab = status
                    }
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.items) { item in
                Button { onOpen(.publication(id: item.id)) } label: {
                    PublicationCard(content: item.publication.cardContent, progress: item.progressPercent)
                }
                .buttonStyle(PressableButtonStyle())
                .overlay(alignment: .topTrailing) { actionsMenu(item) }
            }
        }
    }

    /// Same options per tab as the web library.
    private func actionsMenu(_ item: LibraryItem) -> some View {
        Menu {
            if model.tab == .reading {
                Button { Task { await model.move(item, to: .completed) } } label: {
                    Label("pocket_action_mark_completed", systemImage: "checkmark")
                }
            }
            if model.tab != .owned && item.progressPercent > 0.2 {
                Button { Task { await model.resetProgress(item) } } label: {
                    Label("pocket_action_reset_progress", systemImage: "arrow.counterclockwise")
                }
            }
            if model.tab == .archived {
                Button { Task { await model.move(item, to: .owned) } } label: {
                    Label("pocket_action_unarchive", systemImage: "tray.and.arrow.up")
                }
            } else {
                Button { Task { await model.move(item, to: .archived) } } label: {
                    Label("pocket_action_archive", systemImage: "archivebox")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.35), in: Circle())
                .padding(6)
        }
        .accessibilityLabel(Text("more"))
    }
}

/// Header, continue-reading card, tab chips and the card grid.
private struct PocketSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 160, height: 24)
                SkeletonBlock(width: 220, height: 12)
                SkeletonBlock(height: 120, cornerRadius: 16)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonBlock(width: 96, height: 32, cornerRadius: 16) }
                }
                SkeletonBlock(height: 48, cornerRadius: 12)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in PublicationCardSkeleton() }
                }
            }
            .padding(16)
            .shimmering()
        }
        .scrollDisabled(true)
    }
}
