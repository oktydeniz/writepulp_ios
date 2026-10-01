//
//  PocketComponents.swift
//  writepulp
//

import SwiftUI

/// Last opened item with its progress and a continue button.
struct ContinueReadingCard: View {
    let item: LibraryItem
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("pocket_continue_where_left_off", systemImage: "clock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                Text(item.publication.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(2)
                Text(item.publication.author.fullName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                HStack(spacing: 8) {
                    ProgressView(value: min(item.progressPercent, 100), total: 100)
                        .tint(AppColors.primary)
                    Text(verbatim: String(format: "%.1f%%", item.progressPercent))
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                .padding(.top, 4)
                Button(action: onContinue) {
                    HStack(spacing: 4) {
                        Text("pocket_continue_reading_cta")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.primary, in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AsyncImage(url: AppEnvironment.imageURL(item.publication.coverImg)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            PlaceholderColor.color(for: item.publication.title),
                            PlaceholderColor.color(for: item.publication.title + "x"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Text(item.publication.title.prefix(1).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(AppColors.primaryContainer.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PocketTabChip: View {
    let status: LibraryStatus
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: status.systemImage).font(.system(size: 12))
                Text(status.title).font(.system(size: 13, weight: .medium))
                Text(verbatim: "\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.18), in: Capsule())
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.primary : AppColors.outline.opacity(0.5), in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PocketSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.appLightGray)
            TextField("", text: $text, prompt: Text("pocket_search_hint").foregroundStyle(AppPalette.appLightGray))
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(AppColors.onSurface)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppPalette.appLightGray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppColors.outline) }
    }
}

struct PocketEmptyState: View {
    let status: LibraryStatus
    let onExplore: () -> Void

    var body: some View {
        switch status {
        case .reading:
            EmptyStateView(
                systemImage: "book", title: "pocket_empty_reading_title", message: "pocket_empty_reading_subtitle",
                actionTitle: "pocket_empty_reading_cta", actionSystemImage: "arrow.right", action: onExplore
            )
        case .completed:
            EmptyStateView(systemImage: "checkmark.circle", title: "pocket_empty_completed_title", message: "pocket_empty_completed_subtitle")
        case .owned:
            EmptyStateView(
                systemImage: "bookmark", title: "pocket_empty_owned_title", message: "pocket_empty_owned_subtitle",
                actionTitle: "pocket_empty_owned_cta", actionSystemImage: "arrow.right", action: onExplore
            )
        case .archived:
            EmptyStateView(systemImage: "archivebox", title: "pocket_empty_archived_title", message: "pocket_empty_archived_subtitle")
        }
    }
}
