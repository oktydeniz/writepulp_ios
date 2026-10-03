//
//  SettingsView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct SettingsView: View {
    @State private var model: SettingsViewModel

    init(service: SettingsService, preferences: AppPreferences) {
        _model = State(initialValue: SettingsViewModel(service: service, preferences: preferences))
    }

    var body: some View {
        Group {
            if model.draft != nil {
                form
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
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if model.isDirty { unsavedChangesBar }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isDirty)
        .toast($model.toastMessage)
        .sheet(isPresented: $model.isPickingCategories) {
            CategoryPickerSheet(
                groups: model.categoryGroups,
                isLoading: model.isLoadingCategories,
                selectedIds: model.draft?.categoryPreferences ?? [],
                limit: UserSettings.maxCategories,
                onToggle: { model.toggleCategory($0) }
            )
        }
        .alert("settings_delete_modal_title", isPresented: $model.isConfirmingDelete) {
            SecureField("settings_delete_modal_password_placeholder", text: $model.deletePassword)
            Button("settings_delete_modal_cancel", role: .cancel) { model.deletePassword = "" }
            Button("settings_delete_modal_confirm", role: .destructive) {
                Task { await model.deleteAccount() }
            }
        } message: {
            Text("settings_delete_modal_warning")
        }
        .loadingOverlay(model.isDeleting)
        .task { await model.load() }
    }

    private var form: some View {
        Form {
            Section {
                Picker("settings", selection: $model.tab) {
                    Text("settings_account").tag(SettingsViewModel.Tab.account)
                    Text("settings_preferences").tag(SettingsViewModel.Tab.preferences)
                    Text("settings_notifications").tag(SettingsViewModel.Tab.notifications)
                    Text("settings_privacy").tag(SettingsViewModel.Tab.privacy)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            switch model.tab {
            case .account: accountTab
            case .preferences: preferencesTab
            case .notifications: notificationsTab
            case .privacy: privacyTab
            }
        }
        .scrollContentBackground(.hidden)
        .tint(AppColors.primary)
    }

    private var draft: Binding<UserSettings> {
        Binding(get: { model.draft! }, set: { model.draft = $0 })
    }

    // MARK: - Account

    @ViewBuilder
    private var accountTab: some View {
        Section {
            SettingsToggle("settings_hidden_account", hint: "settings_hidden_account_hint", isOn: draft.isHiddenAccount)
        }

        Section("email") {
            HStack {
                TextField("email", text: draft.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: model.draft?.email) { model.emailChanged() }
                if model.isEmailVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppColors.primary)
                        .accessibilityLabel(Text("settings_verified"))
                }
            }
            if !model.isEmailVerified && !model.isCodeSent && !model.isEmailChanged {
                Text("settings_email_not_verified")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.error)
            }
            if model.isEmailChanged && !model.isCodeSent {
                Button("settings_save_email") { Task { await model.saveEmail() } }
                    .disabled(model.isEmailBusy)
            } else if !model.isEmailChanged && !model.isEmailVerified && !model.isCodeSent {
                Button("settings_verify") { Task { await model.sendCode() } }
                    .disabled(!model.canSendCode)
            }
            if model.isCodeSent {
                HStack {
                    TextField("settings_enter_verify_code", text: $model.verificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    Button("verify") { Task { await model.confirmCode() } }
                        .buttonStyle(.borderless)
                        .disabled(model.isEmailBusy || model.verificationCode.isEmpty)
                }
                Button {
                    Task { await model.sendCode() }
                } label: {
                    Text("settings_resend_code") + Text(" (\(model.sendCount)/\(SettingsViewModel.maxVerificationSends))")
                }
                .disabled(!model.canSendCode)
            }
        }

        Section {
            Text(model.isAuthorOrHigher ? "settings_role_already_author" : "settings_role_upgrade_hint")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.onSurfaceVariant)
            Button("settings_role_upgrade_button") { Task { await model.upgradeToAuthor() } }
                .disabled(model.isUpgradingRole || model.isAuthorOrHigher)
        } header: {
            Text("settings_role_upgrade_title")
        }

        Section {
            DisclosureGroup("settings_change_password", isExpanded: $model.isChangingPassword) {
                SecureField("settings_current_password", text: $model.oldPassword)
                    .textContentType(.password)
                SecureField("settings_new_password", text: $model.newPassword)
                    .textContentType(.newPassword)
                SecureField("settings_confirm_new_password", text: $model.newPasswordConfirmation)
                    .textContentType(.newPassword)
                Button("settings_save_password") { Task { await model.changePassword() } }
                    .disabled(model.isSavingPassword)
            }
        }
    }

    // MARK: - Preferences

    @ViewBuilder
    private var preferencesTab: some View {
        Section {
            SettingsToggle("settings_private_account", hint: "settings_private_account_hint", isOn: draft.isPrivateAccount)
            SettingsToggle(
                "settings_enable_messaging",
                hint: "settings_enable_messaging_hint",
                badge: "settings_coming_soon",
                isOn: draft.isMessageActive
            )
            .disabled(true)
        }
        Section {
            Picker("settings_currency", selection: draft.currencyPreference) {
                ForEach(UserSettings.Currency.selectable, id: \.self) { Text($0.label).tag($0) }
            }
            SettingsToggle("settings_age_restricted", hint: "settings_age_restricted_hint", isOn: draft.showAgeRestricted)
        }
        Section {
            Button {
                Task { await model.openCategoryPicker() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings_manage_category_preferences").foregroundStyle(AppColors.onSurface)
                        if let count = model.draft?.categoryPreferences.count, count > 0 {
                            Text("\(count)/\(UserSettings.maxCategories)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                    Spacer()
                    Text("settings_manage").foregroundStyle(AppColors.primary)
                }
            }
        }
        Section {
            SettingsToggle(
                "settings_inspiration_box",
                hint: "settings_inspiration_box_hint",
                isOn: Binding(get: { model.isInspirationBoxEnabled }, set: { model.isInspirationBoxEnabled = $0 })
            )
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsTab: some View {
        Section {
            SettingsToggle(
                "settings_control_all",
                isOn: Binding(
                    get: { model.draft?.allNotificationsOn ?? false },
                    set: { model.draft?.setAllNotifications($0) }
                )
            )
        }
        Section {
            SettingsToggle("settings_notif_new_chapter", isOn: draft.pushNewChapter)
            SettingsToggle("settings_notif_community", isOn: draft.pushCommunityReply)
            SettingsToggle("settings_notif_coins", isOn: draft.pushCoinRewards)
            SettingsToggle("settings_notif_marketing", isOn: draft.pushPromotions)
            SettingsToggle("settings_notif_followers", isOn: draft.followersAndRequest)
            SettingsToggle("settings_notif_recommendation", isOn: draft.userRecommendations)
            SettingsToggle("settings_notif_lists", isOn: draft.weeklyMonthlyLists)
        }
    }

    // MARK: - Privacy

    @ViewBuilder
    private var privacyTab: some View {
        Section {
            SettingsToggle("settings_save_reading", hint: "settings_save_reading_desc", isOn: draft.saveReadingHistory)
        }
        Section {
            Picker("settings_gender", selection: draft.gender) {
                Text("settings_gender_not_set").tag(UserSettings.Gender?.none)
                ForEach(UserSettings.Gender.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
            }
            SettingsToggle("settings_share_demographic", hint: "settings_share_demographic_hint", isOn: draft.shareDemographicData)
        } footer: {
            Text("settings_gender_hint")
        }
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings_delete_account").foregroundStyle(AppColors.error)
                Text("settings_delete_warning")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            Button("settings_delete_account", role: .destructive) { model.isConfirmingDelete = true }
        } header: {
            Text("settings_danger_zone")
        }
    }

    // MARK: - Save bar

    private var unsavedChangesBar: some View {
        HStack(spacing: 12) {
            Text("settings_unsaved_changes")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("settings_discard") { model.discard() }
                .foregroundStyle(AppColors.onSurfaceVariant)
                .disabled(model.isSaving)
            Button {
                Task { await model.save() }
            } label: {
                Group {
                    if model.isSaving { ProgressView().tint(.white) } else { Text("settings_save_changes") }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.primary, in: Capsule())
            }
            .disabled(model.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Switch with a title, optional hint below and optional badge next to the title.
private struct SettingsToggle: View {
    let title: LocalizedStringKey
    var hint: LocalizedStringKey?
    var badge: LocalizedStringKey?
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, hint: LocalizedStringKey? = nil, badge: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.hint = hint
        self.badge = badge
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).foregroundStyle(AppColors.onSurface)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.12), in: Capsule())
                    }
                }
                if let hint {
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
            }
        }
    }
}
