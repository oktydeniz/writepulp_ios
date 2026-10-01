//
//  CollectionRow.swift
//  writepulp
//

import SwiftUI

/// Card with stacked covers, name, size and follower count. `trailing` holds the row's action button.
struct CollectionRow<Trailing: View>: View {
    let collection: UserCollection
    var showsOwner = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            CoverStack(previews: collection.publications)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(collection.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                        .lineLimit(1)
                    if collection.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .accessibilityLabel(Text("private_collection"))
                    }
                }
                if showsOwner {
                    Text(collection.owner.fullName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                Text("publications_count".localized(collection.publicationSize))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                Label(String(collection.followerCount), systemImage: "person.2.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.onBackground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.primary.opacity(0.12), in: Capsule())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(10)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

extension CollectionRow where Trailing == EmptyView {
    init(collection: UserCollection, showsOwner: Bool = false) {
        self.init(collection: collection, showsOwner: showsOwner) { EmptyView() }
    }
}

/// Up to three covers fanned out, or a placeholder icon for an empty collection.
private struct CoverStack: View {
    let previews: [UserCollection.Preview]

    var body: some View {
        ZStack(alignment: .topLeading) {
            if previews.isEmpty {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(previews.prefix(3).enumerated().reversed()), id: \.element.uuid) { index, preview in
                    AsyncImage(url: AppEnvironment.imageURL(preview.coverImg)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            PlaceholderColor.color(for: preview.uuid)
                        }
                    }
                    .frame(width: 60, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1.5) }
                    .opacity(1 - Double(index) * 0.2)
                    .offset(x: 6 + CGFloat(index) * 10, y: 6 + CGFloat(index) * 4)
                }
            }
        }
        .frame(width: 90, height: 90)
        .background(AppColors.background, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}
