//
//  NotificationsView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct NotificationsView: View {
    let onOpen: (MainRoute) -> Void

    @Environment(\.openURL) private var openURL
    @State private var model: NotificationsViewModel
    @State private var isConfirmingClearAll = false

    init(service: NotificationsService, badge: NotificationBadge, onOpen: @escaping (MainRoute) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: NotificationsViewModel(service: service, badge: badge))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { onOpen(.settings) } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(Text("settings"))
            }
        }
        .confirmationDialog("notification_clear_all", isPresented: $isConfirmingClearAll, titleVisibility: .visible) {
            Button("notification_clear_all", role: .destructive) {
                Task { await model.deleteAll() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("notification_confirm_clear_all")
        }
        .toast($model.toastMessage)
        .task { await model.loadInitial() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("notification_subtitle")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.unreadCount > 0 {
                    Button {
                        Task { await model.markAllRead() }
                    } label: {
                        Label("notification_mark_all_read", systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppColors.primary)
                }
                if !model.items.isEmpty {
                    Button { isConfirmingClearAll = true } label: { Image(systemName: "trash") }
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .accessibilityLabel(Text("notification_clear_all"))
                }
            }
            HStack(spacing: 8) {
                FilterChip(
                    title: Text("notification_all") + Text("  \(model.items.count)"),
                    isSelected: model.filter == .all
                ) { model.filter = .all }
                FilterChip(
                    title: Text("notification_unread") + Text("  \(model.unreadCount)"),
                    isSelected: model.filter == .unread
                ) { model.filter = .unread }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.items.isEmpty {
            ListSkeleton(count: 8, leadingSize: 44)
        } else if let error = model.errorMessage, model.items.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(AppColors.error)
                    .multilineTextAlignment(.center)
                TextLinkButton(title: "retry", color: AppColors.primary) {
                    Task { await model.loadInitial() }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.displayed.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(model.displayed) { item in
                NotificationRow(
                    item: item,
                    onAccept: { Task { await model.respond(to: item, accept: true) } },
                    onDecline: { Task { await model.respond(to: item, accept: false) } }
                )
                .contentShape(Rectangle())
                .onTapGesture { activate(item) }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(item.isRead ? AppColors.background : AppColors.primaryContainer.opacity(0.15))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(item) }
                    } label: {
                        Label("notification_delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if item.id == model.displayed.last?.id, model.filter == .all {
                        Task { await model.loadMore() }
                    }
                }
            }
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await model.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.onSurfaceVariant)
            Text("notification_empty_title")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            Text(model.filter == .unread ? "notification_empty_unread" : "notification_empty_all")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func activate(_ item: NotificationItem) {
        Task { await model.open(item) }
        switch item.target {
        case .route(let route): onOpen(route)
        case .url(let url): openURL(url)
        case .none: break
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Group {
                        if let headline = item.headline { Text(headline) } else { Text(item.type.label) }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.onBackground)
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Formatters.timeAgo(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                    if !item.isRead {
                        Circle().fill(AppColors.primary).frame(width: 8, height: 8)
                    }
                }
                Text(item.message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(3)
                if item.showsActionButtons {
                    HStack(spacing: 8) {
                        Button(action: onAccept) {
                            Text("notification_accept")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.onPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(AppColors.primary, in: Capsule())
                        }
                        Button(action: onDecline) {
                            Text("notification_decline")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if item.senderAvatar?.isEmpty == false {
            Avatar(imagePath: item.senderAvatar, name: item.headline ?? "", size: 40)
        } else {
            Image(systemName: item.type.systemImage)
                .font(.system(size: 17))
                .foregroundStyle(item.type.tint)
                .frame(width: 40, height: 40)
                .background(item.type.tint.opacity(0.15), in: Circle())
        }
    }
}
