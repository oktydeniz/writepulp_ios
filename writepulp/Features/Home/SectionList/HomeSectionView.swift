//
//  HomeSectionView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct HomeSectionView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: HomeSectionViewModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let filters: [PublicationType?] = [nil, .book, .article, .magazine]

    init(
        source: HomeSectionViewModel.Source,
        title: String,
        typeFilter: PublicationType?,
        service: HomeService,
        onOpen: @escaping (MainRoute) -> Void
    ) {
        self.onOpen = onOpen
        _model = State(initialValue: HomeSectionViewModel(source: source, title: title, typeFilter: typeFilter, service: service))
    }

    var body: some View {
        ScrollView {
            if !model.isAuthors {
                filterRow
            }
            if model.isLoading && model.isEmpty {
                PublicationGridSkeleton()
            } else if let error = model.errorMessage, model.isEmpty {
                errorState(error)
            } else {
                grid
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if model.isEmpty { await model.loadFirstPage() } }
        .refreshable { await model.loadFirstPage() }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { type in
                    FilterChip(title: Text(filterTitle(type)), isSelected: model.typeFilter == type) {
                        Task { await model.setTypeFilter(type) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if model.isAuthors {
                ForEach(Array(model.authors.enumerated()), id: \.element.id) { index, author in
                    Button { onOpen(.profile(userId: author.id)) } label: {
                        AuthorCard(author: author, width: nil).padding(.vertical, 8)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .onAppear { loadMoreIfNeeded(index, count: model.authors.count) }
                }
            } else {
                ForEach(Array(model.publications.enumerated()), id: \.element.id) { index, card in
                    Button { onOpen(.publication(id: card.id)) } label: {
                        PublicationCard(content: card.cardContent)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .onAppear { loadMoreIfNeeded(index, count: model.publications.count) }
                }
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            if model.isLoadingMore { ProgressView().offset(y: 24) }
        }
        .padding(.bottom, model.isLoadingMore ? 40 : 0)
    }

    private func loadMoreIfNeeded(_ index: Int, count: Int) {
        guard index >= count - 4 else { return }
        Task { await model.loadMore() }
    }

    private func filterTitle(_ type: PublicationType?) -> LocalizedStringKey {
        switch type {
        case nil: "filter_all"
        case .book: "home_type_filter_book"
        case .article: "home_type_filter_article"
        case .magazine: "home_type_filter_magazine"
        default: type!.label
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.error)
                .multilineTextAlignment(.center)
            TextLinkButton(title: "retry", color: AppColors.primary) {
                Task { await model.loadFirstPage() }
            }
        }
        .padding(24)
        .padding(.top, 40)
    }
}
