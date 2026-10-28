//
//  WalletModels.swift
//  writepulp
//

import SwiftUI

struct Wallet: Decodable {
    let balance: Int
    let totalEarned: Int
    let totalSpent: Int
    /// Part of totalEarned that came from sales of the user's own publications.
    let totalSalesEarned: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balance = try c.decode(Int.self, forKey: .balance)
        totalEarned = try c.decode(Int.self, forKey: .totalEarned)
        totalSpent = try c.decode(Int.self, forKey: .totalSpent)
        totalSalesEarned = try c.decodeIfPresent(Int.self, forKey: .totalSalesEarned) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case balance, totalEarned, totalSpent, totalSalesEarned }
}

/// Transactions of the same type on the same day, summed by the backend.
struct CoinTransaction: Decodable, Identifiable {
    enum Kind: String, Decodable {
        case readingReward = "READING_REWARD"
        case purchase = "PURCHASE"
        case topUp = "TOP_UP"
        case withdrawal = "WITHDRAWAL"
        case refund = "REFUND"
        case purchaseCoin = "PURCHASE_COIN"
        case welcomeBonus = "WELCOME_BONUS"
        case free = "FREE"
        case saleEarning = "SALE_EARNING"

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .free
        }

        var label: LocalizedStringKey {
            switch self {
            case .readingReward: "wallet_type_reading_reward"
            case .purchase: "wallet_type_purchase"
            case .purchaseCoin: "wallet_type_purchase_coin"
            case .topUp: "wallet_type_top_up"
            case .withdrawal: "wallet_type_withdrawal"
            case .refund: "wallet_type_refund"
            case .welcomeBonus: "wallet_type_welcome_bonus"
            case .free: "wallet_type_free"
            case .saleEarning: "wallet_type_sale_earning"
            }
        }

        var systemImage: String {
            switch self {
            case .readingReward: "book.fill"
            case .purchase: "creditcard.fill"
            case .purchaseCoin: "dollarsign.circle.fill"
            case .topUp: "plus"
            case .withdrawal: "chart.line.downtrend.xyaxis"
            case .refund: "arrow.uturn.backward"
            case .welcomeBonus: "gift.fill"
            case .free: "circle.fill"
            case .saleEarning: "chart.line.uptrend.xyaxis"
            }
        }
    }

    let uuid: String
    /// yyyy-MM-dd
    let date: String
    let amount: Int
    let type: Kind
    let description: String?

    /// Grouped rows can share a uuid, so the list id includes the day and type too.
    var id: String { "\(uuid)-\(date)-\(type.rawValue)" }
    var isIncome: Bool { amount > 0 }
}
