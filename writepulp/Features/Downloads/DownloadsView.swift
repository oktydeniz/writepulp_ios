//
//  DownloadsView.swift
//  writepulp
//

import SwiftUI

/// Downloaded publications with update/delete actions and download settings. In offline mode it's
/// the app's root: no back button, and a banner that hands back to the normal flow once online.
@MainActor
struct DownloadsView: View {
    let manager: DownloadManager
    let network: NetworkMonitor
    let preferences: AppPreferences
    var isOffline = false
    let onOpen: (MainRoute) -> Void
    var onReconnect: () -> Void = {}

    @State private var isShowingSettings = false
    @State private var pendingDelete: DownloadedPublication?
    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isOffline {
                OfflineBanner { retryConnection() }
            }
            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("downloads_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(Text("download_settings_title"))
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            DownloadSettingsSheet(preferences: preferences) { manager.setAutoUpdateDays($0) }
        }
        .alert(
            "content_detail_delete_download_title",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { download in
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) { Task { await manager.delete(download.id) } }
        } message: { _ in
            Text("content_detail_delete_download_message")
        }
        .toast($toastMessage)
        .task { await manager.prepare() }
    }

    @ViewBuilder
    private var content: some View {
        if !manager.hasLoaded {
            ListSkeleton(count: 4, leadingSize: 72, isCircle: false)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if manager.downloads.isEmpty {
            EmptyStateView(
                systemImage: "arrow.down.circle",
                title: "downloads_empty_title",
                message: "downloads_empty_message"
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(manager.downloads) { download in
                        DownloadRow(
                            download: download,
                            updateProgress: manager.progress[download.id],
                            coverURL: manager.coverURL(of: download),
                            onOpen: { open(download) },
                            onUpdate: { update(download) },
                            onDelete: { pendingDelete = download }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Actions

    private func open(_ download: DownloadedPublication) {
        onOpen(.reader(publicationId: download.id, type: download.type, chapterId: nil))
    }

    private func update(_ download: DownloadedPublication) {
        guard network.isOnline else {
            toastMessage = String(localized: "downloads_needs_connection")
            return
        }
        Task {
            toastMessage = switch await manager.refresh(download.id) {
            case .completed: String(localized: "downloads_refreshed")
            case .partial: String(localized: "downloads_refresh_partial")
            case .offline: String(localized: "downloads_needs_connection")
            case .failed: String(localized: "downloads_refresh_failed")
            }
        }
    }

    private func retryConnection() {
        if network.isOnline {
            onReconnect()
        } else {
            toastMessage = String(localized: "downloads_still_offline")
        }
    }
}

private struct OfflineBanner: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
            Text("downloads_offline_banner")
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("downloads_reconnect", action: onRetry)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary)
        }
        .foregroundStyle(AppColors.onSurfaceVariant)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.surface)
    }
}
