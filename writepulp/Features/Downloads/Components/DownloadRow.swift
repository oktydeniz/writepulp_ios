//
//  DownloadRow.swift
//  writepulp
//

import SwiftUI

struct DownloadRow: View {
    let download: DownloadedPublication
    /// Set while the copy is being updated.
    let updateProgress: DownloadProgress?
    let coverURL: URL?
    let onOpen: () -> Void
    let onUpdate: () -> Void
    let onDelete: () -> Void

    private var isUpdating: Bool { updateProgress != nil }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    cover
                    details
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isUpdating)

            Menu {
                Button(action: onUpdate) { Label("downloads_update", systemImage: "arrow.clockwise") }
                Button(role: .destructive, action: onDelete) { Label("delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.onBackground)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(isUpdating)
            .accessibilityLabel(Text("downloads_more_actions"))
        }
        .padding(10)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private var cover: some View {
        AsyncImage(url: coverURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    AppColors.skeleton
                    Image(systemName: "book.closed").foregroundStyle(AppColors.onSurfaceVariant)
                }
            }
        }
        .frame(width: 56, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(download.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(download.author.name)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .lineLimit(1)
            status.padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var status: some View {
        if let updateProgress {
            VStack(alignment: .leading, spacing: 4) {
                Text(updateProgress.total > 0
                     ? "downloads_updating_progress".localized(updateProgress.completed, updateProgress.total)
                     : String(localized: "downloads_updating"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                ProgressView(value: updateProgress.fraction)
                    .tint(AppColors.primary)
            }
        } else {
            HStack(spacing: 8) {
                Text(download.type.label)
                Text("downloads_downloaded_on".localized(download.downloadedAt.formatted(date: .abbreviated, time: .omitted)))
                if !download.isComplete {
                    Text("downloads_incomplete").foregroundStyle(AppColors.error)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.onSurfaceVariant)
            .lineLimit(1)
        }
    }
}
