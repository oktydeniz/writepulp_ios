//
//  SearchResultsView.swift
//  writepulp
//

import SwiftUI

/// Result count + filter button over the endless result list; owns the filter sheet.
@MainActor
struct SearchResultsView: View {
    let model: SearchResultsModel
    let onOpen: (MainRoute) -> Void

    @State private var isFiltering = false

    var body: some View {
        VStack(spacing: 0) {
            header
            content.frame(maxHeight: .infinity)
        }
        .sheet(isPresented: $isFiltering) {
            SearchFilterSheet(filters: model.filters) { model.applyFilters($0) }
        }
    }

    private var header: some View {
        HStack {
            if let total = model.results.totalElements, !model.isLoading {
                Text("found_results".localized(total))
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurface)
            }
            Spacer()
            Button { isFiltering = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(model.filters.isDefault ? AppColors.onSurface : AppColors.primary)
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel(Text("filter"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView()
        } else if let error = model.errorMessage, model.results.isEmpty {
            ErrorStateView(message: error) { Task { await model.refresh() } }
        } else if model.results.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", title: "no_results_found")
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(model.results.items.enumerated()), id: \.element.id) { index, item in
                        Button { onOpen(item.route) } label: {
                            SearchResultRow(item: item)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .onAppear {
                            if index >= model.results.items.count - 4 { Task { await model.loadMore() } }
                        }
                    }
                    if model.isLoadingMore {
                        ProgressView().padding(12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await model.refresh() }
        }
    }
}
