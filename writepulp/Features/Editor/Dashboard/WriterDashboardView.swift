//
//  WriterDashboardView.swift
//  writepulp
//

import SwiftUI

/// The writer's works with their totals, and the entry point for a new work.
@MainActor
struct WriterDashboardView: View {
    let navigator: EditorNavigator

    @Environment(SessionStore.self) private var session
    @State private var model: WriterDashboardViewModel
    @State private var isPickingType = false

    init(service: EditorService, navigator: EditorNavigator) {
        self.navigator = navigator
        _model = State(initialValue: WriterDashboardViewModel(service: service))
    }

    private var canWrite: Bool { session.canWrite }

    var body: some View {
        Group {
            if !canWrite {
                EmptyStateView(
                    systemImage: "pencil.and.outline",
                    title: "editor_become_author_title",
                    message: "editor_become_author_message",
                    actionTitle: "settings",
                    actionSystemImage: "gearshape",
                    action: navigator.openSettings
                )
                .frame(maxHeight: .infinity)
            } else if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
                    .frame(maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("editor_my_works")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canWrite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isPickingType = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("editor_new_work"))
                }
            }
        }
        .task(id: canWrite) {
            if canWrite { await model.load() }
        }
        .refreshable { await model.load() }
        .confirmationDialog("editor_new_work", isPresented: $isPickingType, titleVisibility: .visible) {
            ForEach(PublicationType.writable, id: \.self) { type in
                Button { navigator.open(.createWork(type: type)) } label: { Text(type.label) }
            }
        } message: {
            Text("editor_new_work_hint")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let dashboard = model.dashboard {
                    stats(dashboard)
                }
                newWorkButton
                if model.works.isEmpty {
                    EmptyStateView(
                        systemImage: "book.closed",
                        title: "editor_no_works_title",
                        message: "editor_no_works_message"
                    )
                } else {
                    ForEach(model.works) { work in
                        Button { navigator.open(.work(id: work.id)) } label: { WorkCard(work: work) }
                            .buttonStyle(PressableButtonStyle())
                            .task { await model.loadMore(after: work) }
                    }
                    if model.isLoadingMore {
                        ProgressView().padding()
                    }
                }
            }
            .padding(16)
        }
    }

    private func stats(_ dashboard: WriterDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "editor_stat_published", value: dashboard.totalPublished, systemImage: "checkmark.seal")
            StatTile(title: "editor_stat_drafts", value: dashboard.totalDrafts, systemImage: "doc.text")
            StatTile(title: "editor_stat_words", value: dashboard.overallWordCount, systemImage: "text.alignleft")
            StatTile(title: "editor_stat_reads", value: dashboard.overallClicks, systemImage: "eye")
        }
    }

    private var newWorkButton: some View {
        Button { isPickingType = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("editor_new_work")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                    Text("editor_new_work_hint")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            .padding(14)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct StatTile: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.onSurfaceVariant)
            Text(Formatters.compactCount(value))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WorkCard: View {
    let work: WriterWork

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(work.publicationType.label)
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppColors.primary)
                    Text(work.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.onSurface)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                StatusPill(status: work.status)
            }
            HStack(spacing: 14) {
                Label("\(work.sectionCount)", systemImage: "list.bullet")
                Label(Formatters.compactCount(work.wordCount), systemImage: "text.alignleft")
                Label(Formatters.compactCount(work.totalClicks), systemImage: "eye")
                Spacer()
                Text(Formatters.timeAgo(work.updatedAt))
            }
            .font(.system(size: 12))
            .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}

/// Colored status label shared by works and sections.
struct StatusPill: View {
    let status: WorkStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.14), in: Capsule())
    }
}

extension WorkStatus {
    var label: LocalizedStringKey {
        switch self {
        case .draft: "editor_status_draft"
        case .published: "editor_status_published"
        case .hidden: "editor_status_hidden"
        case .removed: "editor_status_removed"
        case .pending, .review: "editor_status_review"
        case .banned: "editor_status_banned"
        case .archived: "editor_status_archived"
        }
    }

    var tint: Color {
        switch self {
        case .published: Color(hex: 0x16A34A)
        case .draft: Color(hex: 0xCA8A04)
        case .hidden, .archived: Color(hex: 0x6B7280)
        case .pending, .review: Color(hex: 0x2563EB)
        case .removed, .banned: AppColors.error
        }
    }
}
