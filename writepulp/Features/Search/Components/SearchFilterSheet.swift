//
//  SearchFilterSheet.swift
//  writepulp
//

import SwiftUI

/// Sort, status, language, rating and reading-time filters; applied together.
struct SearchFilterSheet: View {
    let onApply: (SearchFilters) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchFilters

    init(filters: SearchFilters, onApply: @escaping (SearchFilters) -> Void) {
        self.onApply = onApply
        _draft = State(initialValue: filters)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("sort_by") {
                        FlowLayout(spacing: 8) {
                            ForEach(SearchFilters.Sort.allCases, id: \.self) { sort in
                                chip(sort.title, isSelected: draft.sort == sort) { draft.sort = sort }
                            }
                        }
                    }

                    section("status") {
                        FlowLayout(spacing: 8) {
                            chip("status_all", isSelected: draft.isCompleted == nil) { draft.isCompleted = nil }
                            chip("status_completed", isSelected: draft.isCompleted == true) { draft.isCompleted = true }
                            chip("status_ongoing", isSelected: draft.isCompleted == false) { draft.isCompleted = false }
                        }
                    }

                    section("filter_language") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip("filter_all", isSelected: draft.language == nil) { draft.language = nil }
                                ForEach(ContentLanguage.codes, id: \.self) { code in
                                    FilterChip(
                                        title: Text(verbatim: ContentLanguage.displayName(for: code)),
                                        isSelected: draft.language == code
                                    ) { draft.language = code }
                                }
                            }
                        }
                    }

                    section("min_rating") {
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    draft.minRating = draft.minRating == rating ? 0 : rating
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: draft.minRating >= rating ? "star.fill" : "star")
                                            .font(.system(size: 22))
                                            .foregroundStyle(draft.minRating >= rating ? Color(hex: 0xFFB400) : AppPalette.appLightGray)
                                        Text(verbatim: "\(rating)+")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.onSurface)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("reading_time") {
                        FlowLayout(spacing: 8) {
                            ForEach(SearchFilters.ReadingTime.allCases, id: \.self) { time in
                                chip(time.title, isSelected: draft.readingTime == time) {
                                    draft.readingTime = draft.readingTime == time ? nil : time
                                }
                            }
                        }
                    }

                    PrimaryButton(title: "apply_filters") {
                        onApply(draft)
                        dismiss()
                    }
                }
                .padding(20)
            }
            .navigationTitle("filter_and_sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("clear") { draft = SearchFilters() }
                        .disabled(draft.isDefault)
                }
            }
            .tint(AppColors.primary)
        }
        .presentationDetents([.large])
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
            content()
        }
    }

    private func chip(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        FilterChip(title: Text(title), isSelected: isSelected, action: action)
    }
}
