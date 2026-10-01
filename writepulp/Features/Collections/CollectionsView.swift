//
//  CollectionsView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct CollectionsView: View {
    let onOpen: (MainRoute) -> Void
    let onChange: () -> Void

    @State private var model: CollectionsViewModel
    @State private var editor: EditorTarget?

    private enum EditorTarget: Identifiable {
        case create
        case edit(UserCollection)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let collection): collection.uuid
            }
        }
    }

    init(service: CollectionsService, onOpen: @escaping (MainRoute) -> Void, onChange: @escaping () -> Void = {}) {
        self.onOpen = onOpen
        self.onChange = onChange
        _model = State(initialValue: CollectionsViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("collections", selection: $model.tab) {
                Text("my_collections").tag(CollectionsViewModel.Tab.mine)
                Text("followed_collections").tag(CollectionsViewModel.Tab.followed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.tab == .mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = .create } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("create_new_collection"))
                }
            }
        }
        .sheet(item: $editor) { target in
            switch target {
            case .create:
                CollectionEditorSheet(mode: .create) { form in
                    await saved(model.save(form, editing: nil))
                }
            case .edit(let collection):
                CollectionEditorSheet(mode: .edit(collection)) { form in
                    await saved(model.save(form, editing: collection))
                } onDelete: {
                    await model.delete(collection)
                    onChange()
                }
            }
        }
        .toast($model.toastMessage)
        .task { await model.load() }
        .onChange(of: model.tab) { Task { await model.tabChanged() } }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ListSkeleton(count: 5, leadingSize: 90, isCircle: false)
        } else if let error = model.errorMessage, model.current.isEmpty {
            ErrorStateView(message: error) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
        } else if model.current.isEmpty {
            emptyState.frame(maxHeight: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.current) { collection in
                    Button { onOpen(.collection(id: collection.uuid, name: collection.displayName)) } label: {
                        row(collection)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(16)
        }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func row(_ collection: UserCollection) -> some View {
        if model.tab == .mine {
            CollectionRow(collection: collection) {
                Button { editor = .edit(collection) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.onBackground)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(Text("edit_collection"))
            }
        } else {
            CollectionRow(collection: collection, showsOwner: true) {
                Button { Task { await model.unfollow(collection) } } label: {
                    Image(systemName: "person.badge.minus")
                        .foregroundStyle(AppColors.error)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(Text("follow_unfollow"))
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.tab == .mine {
            EmptyStateView(
                systemImage: "folder",
                title: "no_collections_found",
                message: "you_haven_t_created_collections_yet",
                actionTitle: "create_new_collection",
                action: { editor = .create }
            )
        } else {
            EmptyStateView(
                systemImage: "person.2",
                title: "no_followed_collections_found",
                message: "you_haven_t_followed_collections_yet"
            )
        }
    }

    private func saved(_ error: String?) -> String? {
        if error == nil { onChange() }
        return error
    }
}
