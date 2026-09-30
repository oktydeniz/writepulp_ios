//
//  WalletViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class WalletViewModel {
    enum Filter: CaseIterable, Hashable {
        case all, earned, spent
    }

    private(set) var wallet: Wallet?
    private(set) var transactions: [CoinTransaction] = []
    var filter: Filter = .all
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private var nextPage = 0
    private var hasMore = true
    private let service: WalletService

    init(service: WalletService) {
        self.service = service
    }

    var displayed: [CoinTransaction] {
        switch filter {
        case .all: transactions
        case .earned: transactions.filter(\.isIncome)
        case .spent: transactions.filter { $0.amount < 0 }
        }
    }

    /// Balance and first transactions page together.
    func load() async {
        isLoading = wallet == nil
        defer { isLoading = false }
        async let wallet = service.wallet()
        async let firstPage = service.transactions(page: 0)
        do {
            self.wallet = try await wallet
            let page = try await firstPage
            transactions = page.content
            hasMore = !page.last
            nextPage = 1
            errorMessage = nil
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.transactions(page: nextPage)
            transactions += page.content
            hasMore = !page.last
            nextPage += 1
        } catch {
            // The next scroll retries.
        }
    }
}
