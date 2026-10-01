//
//  WalletService.swift
//  writepulp
//

import Foundation

enum WalletAPI {
    struct PurchaseRequest: Encodable {
        let costInCoin: Int
        let contentId: String
        let type: String
    }

    static func wallet() -> Endpoint<Wallet> {
        Endpoint(path: "wallets/me")
    }

    /// The backend records it as a purchase or a free claim based on the price.
    static func purchase(contentId: String, costInCoin: Int) -> Endpoint<EmptyResponse> {
        let request = PurchaseRequest(costInCoin: costInCoin, contentId: contentId, type: costInCoin > 0 ? "PURCHASE" : "FREE")
        return Endpoint(path: "wallets/purchase", method: .post, body: request)
    }

    static func transactions(page: Int) -> Endpoint<Page<CoinTransaction>> {
        Endpoint(
            path: "wallets/transactions/all",
            query: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "20")]
        )
    }
}

@MainActor
final class WalletService {
    private let api: APIClient

    nonisolated init(api: APIClient) {
        self.api = api
    }

    func wallet() async throws -> Wallet {
        try await api.send(WalletAPI.wallet())
    }

    func transactions(page: Int) async throws -> Page<CoinTransaction> {
        try await api.send(WalletAPI.transactions(page: page))
    }
}
