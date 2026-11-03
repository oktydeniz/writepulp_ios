//
//  WriterDashboardViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class WriterDashboardViewModel {
    private(set) var dashboard: WriterDashboard?
    private(set) var works: [WriterWork] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private var nextPage = 0
    private var hasMore = true
    private let service: EditorService

    init(service: EditorService) {
        self.service = service
    }

    /// First page; keeps what is on screen while it reloads (e.g. back from a work).
    func load() async {
        isLoading = dashboard == nil
        defer { isLoading = false }
        do {
            let result = try await service.dashboard(page: 0)
            dashboard = result
            works = result.publications.content
            hasMore = !result.publications.last
            nextPage = 1
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            if dashboard == nil { errorMessage = error.localizedDescription }
        }
    }

    func loadMore(after work: WriterWork) async {
        guard work.id == works.last?.id, hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await service.dashboard(page: nextPage)
            works += result.publications.content
            hasMore = !result.publications.last
            nextPage += 1
        } catch {
            // The next scroll retries.
        }
    }
}
