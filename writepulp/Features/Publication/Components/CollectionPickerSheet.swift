//
//  CollectionPickerSheet.swift
//  writepulp
//

import SwiftUI

/// Toggle which of the user's collections contain this publication; saves only the difference.
struct CollectionPickerSheet: View {
    let publicationId: String
    let initialIds: Set<String>
    let service: CollectionsService
    let onSaved: () async -> Void
    let onManage: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var collections: [UserCollection] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if collections.isEmpty {
                    EmptyStateView(
                        systemImage: "folder.badge.plus",
                        title: "collection_picker_empty_title",
                        message: "collection_picker_empty_desc",
                        actionTitle: "collection_picker_manage",
                        actionSystemImage: "arrow.right",
                        action: manage
                    )
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("collection_picker_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { Task { await save() } }
                        .disabled(isSaving || selected == initialIds)
                }
            }
            .tint(AppColors.primary)
        }
        .presentationDetents([.medium, .large])
        .task { await load() }
    }

    private var list: some View {
        List {
            Section {
                ForEach(collections) { collection in
                    Button { toggle(collection.uuid) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: collection))
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.displayName)
                                    .foregroundStyle(AppColors.onSurface)
                                Text("publications_count".localized(collection.publicationSize))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.onSurfaceVariant)
                            }
                            Spacer()
                            Image(systemName: selected.contains(collection.uuid) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selected.contains(collection.uuid) ? AppColors.primary : AppPalette.appLightGray)
                        }
                    }
                    .accessibilityAddTraits(selected.contains(collection.uuid) ? .isSelected : [])
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(AppColors.error)
                }
            }
            Section {
                Button("collection_picker_manage", action: manage)
            }
        }
    }

    private func icon(for collection: UserCollection) -> String {
        switch collection.type {
        case .bookmarks: "bookmark.fill"
        case .favorites: "heart.fill"
        case .wishList: "gift.fill"
        default: collection.isPrivate ? "lock.fill" : "folder.fill"
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func manage() {
        dismiss()
        onManage()
    }

    private func load() async {
        selected = initialIds
        defer { isLoading = false }
        do {
            collections = try await service.collections(of: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let toAdd = selected.subtracting(initialIds)
        let toRemove = initialIds.subtracting(selected)
        let failures = await withTaskGroup(of: Bool.self) { group in
            for id in toAdd {
                group.addTask { (try? await service.addPublication(publicationId, to: id)) != nil }
            }
            for id in toRemove {
                group.addTask { (try? await service.removePublication(publicationId, from: id)) != nil }
            }
            var failures = 0
            for await succeeded in group where !succeeded { failures += 1 }
            return failures
        }
        await onSaved()
        if failures > 0 {
            errorMessage = String(localized: "error_some_changes_not_saved")
        } else {
            dismiss()
        }
    }
}
