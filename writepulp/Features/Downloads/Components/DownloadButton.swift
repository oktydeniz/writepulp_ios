//
//  DownloadButton.swift
//  writepulp
//

import SwiftUI

/// Toolbar control for a publication's offline copy: download, progress, downloaded or incomplete.
struct DownloadButton: View {
    let download: DownloadedPublication?
    let progress: DownloadProgress?
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: tapped) {
            ZStack {
                if let progress {
                    Circle()
                        .stroke(AppColors.onBackground.opacity(0.15), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: max(progress.fraction, 0.04))
                        .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.25), value: progress.fraction)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            .padding(progress == nil ? 0 : 8)
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
        }
        .disabled(progress != nil)
        .accessibilityLabel(Text(accessibilityKey))
    }

    private func tapped() {
        if let download, download.isComplete {
            onDelete()
        } else {
            onDownload()
        }
    }

    private var iconName: String {
        guard let download else { return "arrow.down.to.line" }
        return download.isComplete ? "checkmark.circle.fill" : "exclamationmark.arrow.circlepath"
    }

    private var iconColor: Color {
        guard let download else { return AppColors.onBackground }
        return download.isComplete ? AppColors.primary : AppColors.error
    }

    private var accessibilityKey: LocalizedStringKey {
        guard let download else { return "content_detail_download" }
        return download.isComplete ? "content_detail_downloaded" : "content_detail_download_incomplete"
    }
}
