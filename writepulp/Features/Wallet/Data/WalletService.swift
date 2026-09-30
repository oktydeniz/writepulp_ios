//
//  WalletService.swift
//  writepulp
//

import Foundation

enum WalletAPI {
    static func wallet() -> Endpoint<Wallet> {
        Endpoint(path: "wallets/me")
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
