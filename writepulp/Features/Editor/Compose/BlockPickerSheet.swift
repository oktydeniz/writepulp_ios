//
//  BlockPickerSheet.swift
//  writepulp
//

import SwiftUI

/// Grouped, searchable list of block types to insert.
struct BlockPickerSheet: View {
    let onPick: (BlockKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private func matches(_ kind: BlockKind) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return kind.localizedName.localizedCaseInsensitiveContains(query)
            || kind.rawValue.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(BlockKind.Group.allCases) { group in
                        let kinds = group.kinds.filter(matches)
                        if !kinds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppColors.onSurfaceVariant)
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(kinds) { kind in tile(kind) }
                                }
                            }
                        }
                    }
                    if !BlockKind.allCases.contains(where: matches) {
                        Text("editor_no_block_found")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("editor_search_blocks"))
            .navigationTitle("editor_add_block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tile(_ kind: BlockKind) -> some View {
        Button {
            dismiss()
            onPick(kind)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Text(kind.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
