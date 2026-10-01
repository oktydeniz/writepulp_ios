//
//  CategoryExploreView.swift
//  writepulp
//

import SwiftUI

/// Everything published in one category, with publication-type chips and filters.
@MainActor
struct CategoryExploreView: View {
    let title: String
    let onOpen: (MainRoute) -> Void

    @State private var model: SearchResultsModel

    init(slug: String, title: String, service: SearchService, onOpen: @escaping (MainRoute) -> Void) {
        self.title = title
        self.onOpen = onOpen
        _model = State(initialValue: SearchResultsModel(service: service, categorySlug: slug))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchTypeChips(types: SearchType.publicationTypes, selection: model.type) { model.setType($0) }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            SearchResultsView(model: model, onOpen: onOpen)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !model.results.hasLoaded { model.search(query: "") } }
    }
}
