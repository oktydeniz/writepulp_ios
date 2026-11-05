//
//  DeleteAccountSheet.swift
//  writepulp
//

import SwiftUI

/// States what deleting the account does to the balance and the works before asking to confirm.
struct DeleteAccountSheet: View {
    @Bindable var model: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("settings_delete_modal_warning")
                        .foregroundStyle(AppColors.error)
                }
                Section("settings_delete_info_title") {
                    Label("settings_delete_info_personal", systemImage: "person.crop.circle.badge.xmark")
                    Label(balanceText, systemImage: "creditcard")
                    Label(worksText, systemImage: "book.closed")
                    Label("settings_delete_info_content", systemImage: "text.bubble")
                    if model.deletionPreview?.appleLinked == true {
                        Label("settings_delete_info_apple", systemImage: "apple.logo")
                    }
                    Link("settings_delete_policy_link", destination: AppLinks.privacyPolicy)
                }
                .font(.subheadline)
                Section {
                    Toggle("settings_delete_acknowledge", isOn: $model.deleteAcknowledged)
                        .font(.subheadline)
                    if model.requiresDeletePassword {
                        SecureField("settings_delete_modal_password_placeholder", text: $model.deletePassword)
                            .textContentType(.password)
                    }
                }
                Section {
                    Button("settings_delete_modal_confirm", role: .destructive) {
                        Task { await model.deleteAccount() }
                    }
                    .disabled(!model.canConfirmDelete || model.isDeleting)
                }
            }
            .navigationTitle("settings_delete_modal_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings_delete_modal_cancel") { dismiss() }
                }
            }
            .loadingOverlay(model.isDeleting)
            .toast($model.toastMessage)
            .task { await model.loadDeletionPreview() }
        }
    }

    private var balanceText: LocalizedStringKey {
        if let coins = model.deletionPreview?.coinBalance, coins > 0 {
            return "settings_delete_info_balance_amount \(coins)"
        }
        return "settings_delete_info_balance"
    }

    private var worksText: LocalizedStringKey {
        if let preview = model.deletionPreview, preview.retainedPublicationCount > 0 {
            return "settings_delete_info_works_amount \(preview.retainedPublicationCount) \(preview.readerCount)"
        }
        return "settings_delete_info_works"
    }
}
