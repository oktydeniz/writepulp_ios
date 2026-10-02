//
//  ReviewsViewModel.swift
//  writepulp
//

import Foundation
import Observation

/// Where reviews are read from and written to: a publication, or a single section.
protocol ReviewsSource {
    func reviews(page: Int) async throws -> Page<Review>
    func save(editing reviewId: String?, _ request: ReviewRequest) async throws
    func delete(reviewId: String) async throws
}

struct PublicationReviewsSource: ReviewsSource {
    let publicationId: String
    let service: PublicationService

    func reviews(page: Int) async throws -> Page<Review> {
        try await service.reviews(publicationId: publicationId, page: page)
    }

    func save(editing reviewId: String?, _ request: ReviewRequest) async throws {
        _ = try await service.saveReview(publicationId: publicationId, editing: reviewId, request)
    }

    func delete(reviewId: String) async throws {
        try await service.deleteReview(publicationId: publicationId, reviewId: reviewId)
    }
}

/// Reviews plus the viewer's write/edit form.
@MainActor
@Observable
final class ReviewsViewModel {
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

    private let source: any ReviewsSource
    private let session: () -> (isSignedIn: Bool, userId: String?)

    init(source: any ReviewsSource, session: @escaping () -> (isSignedIn: Bool, userId: String?)) {
        self.source = source
        self.session = session
    }

    var currentUserId: String? { session().userId }
    var isSignedIn: Bool { session().isSignedIn }
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.items.map(\.rating).reduce(0, +)) / Double(reviews.items.count)
    }
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
            reviews.apply(try await source.reviews(page: 0), replacing: true)
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
            reviews.apply(try await source.reviews(page: reviews.nextPage), replacing: false)
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
            try await source.save(
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
            try await source.delete(reviewId: review.id)
            if editingId == review.id { cancelEditing() }
            toastMessage = String(localized: "review_deleted")
            await reload()
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    private func reload() async {
        if let page = try? await source.reviews(page: 0) {
            reviews.apply(page, replacing: true)
        }
        await onChange()
    }
}
