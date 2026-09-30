//
//  WalletView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct WalletView: View {
    @State private var model: WalletViewModel

    init(service: WalletService) {
        _model = State(initialValue: WalletViewModel(service: service))
    }

    var body: some View {
        Group {
            if let wallet = model.wallet {
                content(wallet)
            } else if let error = model.errorMessage {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(AppColors.error).multilineTextAlignment(.center)
                    TextLinkButton(title: "retry", color: AppColors.primary) { Task { await model.load() } }
                }
                .padding(32)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func content(_ wallet: Wallet) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                balanceCard(wallet)
                howToEarnCard
                historyHeader
                if model.displayed.isEmpty {
                    emptyState
                } else {
                    ForEach(model.displayed) { transaction in
                        TransactionRow(transaction: transaction)
                            .onAppear {
                                if transaction.id == model.displayed.last?.id {
                                    Task { await model.loadMore() }
                                }
                            }
                    }
                }
                if model.isLoadingMore {
                    ProgressView().padding()
                }
            }
            .padding(16)
        }
        .refreshable { await model.load() }
    }

    private func balanceCard(_ wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("wallet_balance")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 26))
                    Text("\(wallet.balance)").font(.system(size: 30, weight: .bold))
                }
                .foregroundStyle(.white)
                Text("wallet_coins_balance".localized(wallet.balance))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: 24) {
                stat(systemImage: "chart.line.uptrend.xyaxis", label: "wallet_total_earned", value: wallet.totalEarned)
                stat(systemImage: "chart.line.downtrend.xyaxis", label: "wallet_total_spent", value: wallet.totalSpent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppPalette.primaryColor, AppPalette.primaryColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private func stat(systemImage: String, label: LocalizedStringKey, value: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 13))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.system(size: 16, weight: .bold))
                Text(label).font(.system(size: 11)).opacity(0.85)
            }
        }
        .foregroundStyle(.white)
    }

    private var howToEarnCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("wallet_how_to_earn")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.onBackground)
                Text("wallet_read_articles_desc")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppColors.secondaryContainer.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("wallet_history")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            HStack(spacing: 8) {
                ForEach(WalletViewModel.Filter.allCases, id: \.self) { option in
                    FilterChip(title: Text(title(for: option)), isSelected: model.filter == option) {
                        model.filter = option
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(for filter: WalletViewModel.Filter) -> LocalizedStringKey {
        switch filter {
        case .all: "filter_all"
        case .earned: "wallet_filter_earned"
        case .spent: "wallet_filter_spent"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.onSurfaceVariant)
            Text("wallet_no_transactions")
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .padding(.vertical, 48)
    }
}

private struct TransactionRow: View {
    let transaction: CoinTransaction

    private var color: Color { transaction.isIncome ? Color(hex: 0x3DAA72) : AppColors.error }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type.systemImage)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.type.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.onSurface)
                if transaction.type != .readingReward, let description = transaction.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                Text(Formatters.mediumDate(transaction.date))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Text("\(transaction.isIncome ? "+" : "")\(transaction.amount)")
                    .font(.system(size: 15, weight: .bold))
                Image(systemName: "dollarsign.circle.fill").font(.system(size: 13))
            }
            .foregroundStyle(color)
        }
        .padding(12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
