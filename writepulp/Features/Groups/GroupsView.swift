//
//  GroupsView.swift
//  writepulp
//

import SwiftUI

/// My communities (managed + joined) and explore with search.
@MainActor
struct GroupsView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: GroupsViewModel
    @FocusState private var isSearchFocused: Bool

    init(service: GroupsService, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: GroupsViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("groups", selection: $model.tab) {
                Text("my_groups").tag(GroupsViewModel.Tab.mine)
                Text("all_groups").tag(GroupsViewModel.Tab.explore)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if model.tab == .explore {
                SearchField(
                    text: $model.query,
                    isFocused: $isSearchFocused,
                    onClear: { model.query = "" },
                    placeholder: "search_communities_placeholder"
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { onOpen(.createGroup) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("create_community"))
            }
        }
        .toast($model.toastMessage)
        .alert(item: $model.notice) { notice in
            switch notice {
            case .requestSent:
                Alert(
                    title: Text("join_request_sent"),
                    message: Text("we_will_send_you_a_notification_when_the_request_is_approved")
                )
            case .requestWithdrawn:
                Alert(title: Text("join_request_withdrawn"), message: Text("your_join_request_has_been_withdrawn"))
            }
        }
        // Reloads on every visit: membership may have changed inside a community.
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ListSkeleton(count: 6, leadingSize: 48)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if let error = model.errorMessage, !model.hasLoaded {
            ErrorStateView(message: error) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
        } else {
            switch model.tab {
            case .mine: myGroups
            case .explore: exploreGroups
            }
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var myGroups: some View {
        if model.owned.isEmpty && model.joinedOnly.isEmpty {
            EmptyStateView(systemImage: "person.3", title: "no_groups_found", message: "no_joined_communities_desc")
                .frame(maxHeight: .infinity)
        } else {
            list {
                if !model.owned.isEmpty {
                    sectionHeader("managed_by_me")
                    ForEach(model.owned) { row($0) }
                }
                if !model.joinedOnly.isEmpty {
                    sectionHeader("joined_communities")
                        .padding(.top, model.owned.isEmpty ? 0 : 8)
                    ForEach(model.joinedOnly) { row($0) }
                }
            }
        }
    }

    @ViewBuilder
    private var exploreGroups: some View {
        if model.isSearchActive && model.isSearching && model.searchResults.isEmpty {
            ListSkeleton(count: 4, leadingSize: 48)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if model.exploreList.isEmpty {
            EmptyStateView(
                systemImage: model.isSearchActive ? "magnifyingglass" : "globe",
                title: model.isSearchActive ? "no_search_results_title" : "no_explore_communities_title",
                message: model.isSearchActive ? "no_search_results_desc" : "no_explore_communities_desc"
            )
            .frame(maxHeight: .infinity)
        } else {
            list {
                ForEach(model.exploreList) { row($0) }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func list<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                content()
                if model.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
            .padding(16)
        }
        .refreshable { await model.load() }
    }

    private func row(_ group: CommunityGroup) -> some View {
        GroupRow(
            group: group,
            isProcessing: model.processingId == group.id,
            onOpen: { onOpen(.community(id: group.id, name: group.name)) },
            onJoin: { Task { await model.join(group) } },
            onWithdraw: { Task { await model.withdrawRequest(group) } }
        )
        .task { await model.loadMoreIfNeeded(after: group) }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.onSurfaceVariant)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}
