//
//  GroupRequestsView.swift
//  writepulp
//

import Observation
import SwiftUI

@MainActor
@Observable
final class GroupRequestsViewModel {
    let groupId: String
    private(set) var requests = PagedList<GroupJoinRequest>()
    private(set) var isLoading = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    var isSelecting = false {
        didSet { if !isSelecting { selection = [] } }
    }
    var selection: Set<String> = []
    var toastMessage: String?

    private let service: GroupsService

    init(groupId: String, service: GroupsService) {
        self.groupId = groupId
        self.service = service
    }

    func load() async {
        isLoading = !requests.hasLoaded
        defer { isLoading = false }
        do {
            requests.apply(try await service.requests(id: groupId, page: 0), replacing: true)
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if requests.hasLoaded { toastMessage = error.localizedDescription } else { errorMessage = error.localizedDescription }
        }
    }

    func loadMoreIfNeeded(after request: GroupJoinRequest) async {
        guard request.id == requests.items.last?.id, requests.hasMore else { return }
        if let page = try? await service.requests(id: groupId, page: requests.nextPage) {
            requests.apply(page, replacing: false)
        }
    }

    func toggleSelection(_ request: GroupJoinRequest) {
        if selection.contains(request.id) { selection.remove(request.id) } else { selection.insert(request.id) }
    }

    func handle(_ request: GroupJoinRequest, accept: Bool) async {
        await perform {
            try await self.service.handleRequest(requestId: request.id, accept: accept)
            self.requests.removeAll { $0.id == request.id }
            self.toastMessage = String(localized: accept ? "request_accepted" : "request_declined")
        }
    }

    func handleSelected(accept: Bool) async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        await perform {
            try await self.service.handleRequests(id: self.groupId, requestIds: ids, approve: accept)
            self.requests.removeAll { ids.contains($0.id) }
            self.isSelecting = false
            self.toastMessage = String(localized: accept ? "request_accepted" : "request_declined")
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
        } catch {
            toastMessage = error.localizedDescription
        }
    }
}

/// Pending join requests of a private community, accepted or declined one by one or in bulk.
@MainActor
struct GroupRequestsView: View {
    let onOpen: (MainRoute) -> Void

    @State private var model: GroupRequestsViewModel

    init(groupId: String, service: GroupsService, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: GroupRequestsViewModel(groupId: groupId, service: service))
    }

    var body: some View {
        content
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(model.isSelecting ? Text("selected_count".localized(model.selection.count)) : Text("manage_members_requests"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !model.requests.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(model.isSelecting ? "cancel" : "select") { model.isSelecting.toggle() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.isSelecting { selectionBar }
            }
            .toast($model.toastMessage)
            .loadingOverlay(model.isBusy)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ListSkeleton(count: 6, leadingSize: 44)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if let error = model.errorMessage {
            ErrorStateView(message: error) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
        } else if model.requests.isEmpty {
            EmptyStateView(systemImage: "person.crop.circle.badge.checkmark", title: "no_request_found")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(model.requests.items) { request in
                    row(request)
                        .listRowBackground(AppColors.surface)
                        .task { await model.loadMoreIfNeeded(after: request) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await model.load() }
        }
    }

    private func row(_ request: GroupJoinRequest) -> some View {
        HStack(spacing: 12) {
            if model.isSelecting {
                Image(systemName: model.selection.contains(request.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.primary)
            }
            Avatar(imagePath: request.userAvatar, name: request.userName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.userName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(1)
                Text(subtitle(request))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !model.isSelecting {
                Button { Task { await model.handle(request, accept: false) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.error)
                        .frame(width: 36, height: 36)
                        .background(AppColors.error.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("decline"))
                Button { Task { await model.handle(request, accept: true) } } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.onPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("accept"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isSelecting { model.toggleSelection(request) } else { onOpen(.profile(userId: request.userId)) }
        }
    }

    private func subtitle(_ request: GroupJoinRequest) -> String {
        let handle = request.userHandle.isEmpty ? "" : "@\(request.userHandle)"
        guard let date = request.requestedAt else { return handle }
        let ago = date.formatted(.relative(presentation: .named))
        return handle.isEmpty ? ago : "\(handle) · \(ago)"
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) { Task { await model.handleSelected(accept: false) } } label: {
                Text("decline_selected".localized(model.selection.count)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button { Task { await model.handleSelected(accept: true) } } label: {
                Text("accept_selected".localized(model.selection.count)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .tint(AppColors.primary)
        .disabled(model.selection.isEmpty)
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
