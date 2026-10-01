//
//  SearchView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct SearchView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: SearchViewModel
    @FocusState private var isFieldFocused: Bool

    init(service: SearchService, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: SearchViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                SearchField(text: $model.query, isFocused: $isFieldFocused) { model.clear() }
                if model.isSearching {
                    SearchTypeChips(types: SearchType.allCases, selection: model.results.type) {
                        isFieldFocused = false
                        model.results.setType($0)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if model.isSearching {
                SearchResultsView(model: model.results, onOpen: open)
            } else {
                categories
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onChange(of: model.query) { model.queryChanged() }
        .task { await model.loadCategories() }
    }

    @ViewBuilder
    private var categories: some View {
        if model.isLoadingCategories && model.categories.isEmpty {
            ListSkeleton(count: 6, leadingSize: 24, isCircle: false)
        } else if let error = model.categoriesError, model.categories.isEmpty {
            ErrorStateView(message: error) { Task { await model.loadCategories() } }
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(model.categories) { group in
                        CategoryGroupCard(group: group) { category in
                            open(category: category)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func open(_ route: MainRoute) {
        isFieldFocused = false
        onOpen(route)
    }

    private func open(category: CategoryGroup.Category) {
        guard let slug = category.slug else { return }
        open(.categoryExplore(slug: slug, title: category.name))
    }
}
