//
//  DownloadSettingsSheet.swift
//  writepulp
//

import SwiftUI

struct DownloadSettingsSheet: View {
    let preferences: AppPreferences
    let onAutoUpdateDaysChange: (Int) -> Void

    /// 0 = never.
    private static let autoUpdateOptions = [7, 14, 30, 0]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("download_settings_title")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.onBackground)

            Toggle(isOn: Binding(
                get: { preferences.isDownloadMediaEnabled },
                set: { preferences.setDownloadMediaEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("download_settings_media")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.onSurface)
                    Text("download_settings_media_description")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
            }
            .tint(AppColors.primary)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("download_settings_auto_update")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.onSurface)
                Text("download_settings_auto_update_description")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }

            HStack(spacing: 8) {
                ForEach(Self.autoUpdateOptions, id: \.self) { days in
                    FilterChip(
                        title: Text(days > 0
                                    ? "download_settings_days".localized(days)
                                    : String(localized: "download_settings_never")),
                        isSelected: preferences.downloadAutoUpdateDays == days
                    ) {
                        onAutoUpdateDaysChange(days)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
