//
//  CollectionDetailView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct CollectionDetailView: View {
    let title: String
    let onOpen: (MainRoute) -> Void

    @State private var model: CollectionDetailViewModel

    init(collectionId: String, title: String, service: CollectionsService, onOpen: @escaping (MainRoute) -> Void) {
        self.title = title
        self.onOpen = onOpen
        _model = State(initialValue: CollectionDetailViewModel(collectionId: collectionId, service: service))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let detail = model.detail, !detail.isMe {
                    ToolbarItem(placement: .topBarTrailing) {
                        FollowButton(
                            title: detail.isFollowing ? "following" : "follow",
                            systemImage: detail.isFollowing ? "checkmark" : "plus",
                            isActive: detail.isFollowing,
                            height: 32
                        ) {
                            Task { await model.toggleFollow() }
                        }
                    }
                }
            }
            .toast($model.toastMessage)
            .task { if model.detail == nil { await model.load() } }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView()
        } else if let error = model.errorMessage, model.detail == nil {
            ErrorStateView(message: error) { Task { await model.load() } }
        } else if model.items.isEmpty {
            EmptyStateView(systemImage: "doc.text", title: "collection_is_empty", message: "no_publications_added_yet")
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(Array(model.items.items.enumerated()), id: \.element.id) { index, item in
                Button { onOpen(.publication(id: item.id)) } label: {
                    CollectionItemRow(item: item)
                }
                .buttonStyle(PressableButtonStyle())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing) {
                    if model.detail?.isMe == true {
                        Button(role: .destructive) {
                            Task { await model.remove(item) }
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                }
                .onAppear {
                    if index >= model.items.items.count - 3 { Task { await model.loadMore() } }
                }
            }
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await model.load() }
    }
}

private struct CollectionItemRow: View {
    let item: CollectionItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: AppEnvironment.imageURL(item.imageUrl)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    PlaceholderColor.color(for: item.title)
                        .overlay {
                            Text(item.title.prefix(1).uppercased())
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: 64, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                if let type = item.contentType {
                    Text(type.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.onSurface)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.primaryContainer, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subTitle = item.subTitle, !subTitle.isEmpty {
                    Text(subTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    if let rating = item.rating, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    }
                    if let readTime = Formatters.readTime(minutes: item.estimatedReadTime) {
                        Label(readTime, systemImage: "clock")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
