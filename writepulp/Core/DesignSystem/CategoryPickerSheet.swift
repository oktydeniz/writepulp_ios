//
//  CategoryPickerSheet.swift
//  writepulp
//

import SwiftUI

/// Grouped category chips with a selection limit.
struct CategoryPickerSheet: View {
    let groups: [CategoryGroup]
    let isLoading: Bool
    let selectedIds: Set<String>
    let limit: Int
    let onToggle: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.parent.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColors.primary)
                                FlowLayout(spacing: 8) {
                                    ForEach(group.subCategories, id: \.identity) { category in
                                        chip(category)
                                    }
                                }
                            }
                            Divider()
                        }
                    }
                    .padding(16)
                }
            }
            .background(AppColors.surface.ignoresSafeArea())
            .navigationTitle("select_category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(selectedIds.count)/\(limit)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ok") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func chip(_ category: CategoryGroup.Category) -> some View {
        let id = category.id ?? ""
        let selected = selectedIds.contains(id)
        let limitReached = selectedIds.count >= limit
        return FilterChip(title: Text(category.name), isSelected: selected) {
            onToggle(id)
        }
        .disabled(id.isEmpty || (!selected && limitReached))
        .opacity(!selected && limitReached ? 0.4 : 1)
    }
}
