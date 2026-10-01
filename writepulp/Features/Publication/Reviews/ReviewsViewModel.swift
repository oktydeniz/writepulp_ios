//
//  ReviewsViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// A publication's reviews plus the viewer's write/edit form.
@MainActor
@Observable
final class ReviewsViewModel {
    let publicationId: String
    private(set) var reviews = PagedList<Review>()
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isSubmitting = false
    var rating = 0
    var comment = ""
    private(set) var editingId: String?
    var toastMessage: String?
    /// Called after a change so the screen can refetch the average and count.
    var onChange: () async -> Void = {}

    private let service: PublicationService

    init(publicationId: String, service: PublicationService) {
        self.publicationId = publicationId
        self.service = service
    }

    var currentUserId: String? { service.currentUserId }
    var isSignedIn: Bool { service.isSignedIn }
    var isEditing: Bool { editingId != nil }
    var myReview: Review? { reviews.items.first { $0.user.uuid == currentUserId } }

    func canWrite(isOwner: Bool) -> Bool {
        !isOwner && isSignedIn && myReview == nil && !isEditing
    }

    func loadIfNeeded() async {
        guard !reviews.hasLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            reviews.apply(try await service.reviews(publicationId: publicationId, page: 0), replacing: true)
        } catch APIError.cancelled {
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard reviews.hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            reviews.apply(try await service.reviews(publicationId: publicationId, page: reviews.nextPage), replacing: false)
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func startEditing(_ review: Review) {
        editingId = review.id
        rating = review.rating
        comment = review.comment ?? ""
    }

    func cancelEditing() {
        editingId = nil
        rating = 0
        comment = ""
    }

    func submit() async {
        guard rating > 0 else {
            toastMessage = String(localized: "review_rating_required")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasEditing = isEditing
        do {
            _ = try await service.saveReview(
                publicationId: publicationId,
                editing: editingId,
                ReviewRequest(rating: rating, comment: trimmed.isEmpty ? nil : trimmed)
            )
            cancelEditing()
            toastMessage = wasEditing ? String(localized: "review_updated") : String(localized: "review_submitted")
            await reload()
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    func delete(_ review: Review) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await service.deleteReview(publicationId: publicationId, reviewId: review.id)
            if editingId == review.id { cancelEditing() }
            toastMessage = String(localized: "review_deleted")
            await reload()
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    private func reload() async {
        if let page = try? await service.reviews(publicationId: publicationId, page: 0) {
            reviews.apply(page, replacing: true)
        }
        await onChange()
    }
}
