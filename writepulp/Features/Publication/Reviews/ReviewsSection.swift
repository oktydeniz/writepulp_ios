//
//  ReviewsSection.swift
//  writepulp
//

import SwiftUI

@MainActor
struct ReviewsSection: View {
    let model: ReviewsViewModel
    let reviewAverage: Double
    let reviewCount: Int
    let isOwner: Bool
    let onSignIn: () -> Void
    let onOpenProfile: (String) -> Void

    @State private var pendingDelete: Review?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            summary

            if isOwner {
                hint("review_owner_hint")
            } else if !model.isSignedIn {
                VStack(spacing: 8) {
                    hint("review_login_hint")
                    TextLinkButton(title: "sign_in", color: AppColors.primary, action: onSignIn)
                }
                .frame(maxWidth: .infinity)
            }

            if model.canWrite(isOwner: isOwner) || model.isEditing {
                ReviewForm(model: model)
            }

            list
        }
        .task { await model.loadIfNeeded() }
        .alert("review_delete_confirm", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                if let review = pendingDelete { Task { await model.delete(review) } }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text(verbatim: String(format: "%.1f", reviewAverage))
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(AppColors.onBackground)
            StarRow(rating: Int(reviewAverage.rounded()), size: 18)
            Text("review_rating_count".localized(reviewCount))
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var list: some View {
        if model.isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(24)
        } else if model.reviews.isEmpty {
            hint("review_empty")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(model.reviews.items) { review in
                    ReviewRow(
                        review: review,
                        isMine: review.user.uuid == model.currentUserId,
                        onAuthor: { onOpenProfile(review.user.uuid) },
                        onEdit: { model.startEditing(review) },
                        onDelete: { pendingDelete = review }
                    )
                }
                if model.reviews.hasMore {
                    Button {
                        Task { await model.loadMore() }
                    } label: {
                        if model.isLoadingMore {
                            ProgressView()
                        } else {
                            Text("notification_load_more")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func hint(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 14))
            .foregroundStyle(AppColors.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

@MainActor
private struct ReviewForm: View {
    @Bindable var model: ReviewsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.isEditing ? "review_edit_title" : "review_write")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.onSurface)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button { model.rating = star } label: {
                        Image(systemName: star <= model.rating ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundStyle(AppPalette.goldAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(star)"))
                }
            }

            TextField(
                "",
                text: $model.comment,
                prompt: Text("review_comment_placeholder").foregroundStyle(AppPalette.appLightGray),
                axis: .vertical
            )
            .lineLimit(3...6)
            .foregroundStyle(AppColors.onSurface)
            .padding(12)
            .background(AppColors.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppColors.outline) }

            HStack {
                if model.isEditing {
                    TextLinkButton(title: "cancel", color: AppColors.onSurfaceVariant) { model.cancelEditing() }
                }
                Spacer()
                Button { Task { await model.submit() } } label: {
                    Group {
                        if model.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(model.isEditing ? "save" : "review_submit")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppColors.primary.opacity(model.rating > 0 ? 1 : 0.5), in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.isSubmitting || model.rating == 0)
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline) }
    }
}

private struct ReviewRow: View {
    let review: Review
    let isMine: Bool
    let onAuthor: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onAuthor) {
                Avatar(imagePath: review.user.avatarImg, name: review.user.fullName, size: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(review.user.fullName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.onSurface)
                        Text(Formatters.timeAgo(review.createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                    Spacer()
                    if isMine {
                        Menu {
                            Button(action: onEdit) { Label("review_edit_action", systemImage: "pencil") }
                            Button(role: .destructive, action: onDelete) { Label("delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(AppColors.onSurfaceVariant)
                                .frame(width: 30, height: 24)
                        }
                    }
                }
                StarRow(rating: review.rating, size: 12)
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurface.opacity(0.85))
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StarRow: View {
    let rating: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(AppPalette.goldAccent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(rating)/5"))
    }
}
