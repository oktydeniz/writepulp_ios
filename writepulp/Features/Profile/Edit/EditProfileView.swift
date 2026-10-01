//
//  EditProfileView.swift
//  writepulp
//

import PhotosUI
import SwiftUI

@MainActor
struct EditProfileView: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: EditProfileViewModel
    @State private var isChoosingAvatarAction = false
    @State private var isPickingPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSocialExpanded = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case fullName, email, handle, about, location
        case social(SocialPlatform)
    }

    init(service: ProfileService, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _model = State(initialValue: EditProfileViewModel(service: service))
    }

    var body: some View {
        Group {
            if model.draft != nil {
                form
            } else if let error = model.errorMessage {
                ErrorStateView(message: error) { Task { await model.load() } }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("edit_profile")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(model.isSaving)
        .confirmationDialog("change_avatar", isPresented: $isChoosingAvatarAction, titleVisibility: .visible) {
            Button("choose_from_gallery") { isPickingPhoto = true }
            if model.hasAvatar {
                Button("delete", role: .destructive) { model.removeAvatar() }
            }
            Button("cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { Task { await loadPickedPhoto() } }
        .alert("error_title", isPresented: errorBinding) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("profile_updated", isPresented: $model.didSave) {
            Button("ok") {
                onSaved()
                dismiss()
            }
        } message: {
            Text("profile_updated_successfully")
        }
        .task { await model.load() }
    }

    /// Only save/validation errors; a failed first load shows the retry state instead.
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.draft != nil && model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var draft: Binding<EditableProfile> {
        Binding(get: { model.draft! }, set: { model.draft = $0 })
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar
                    .padding(.vertical, 8)

                AuthTextField(
                    label: "full_name", placeholder: String(localized: "full_name"),
                    text: limited(draft.fullName, to: EditProfileViewModel.maxNameLength),
                    focus: $focus, field: .fullName, systemImage: "person",
                    contentType: .name, onSubmit: { focus = .email }
                )

                VStack(alignment: .leading, spacing: 8) {
                    AuthTextField(
                        label: "email", placeholder: String(localized: "your_email_com"),
                        text: draft.email, focus: $focus, field: .email,
                        systemImage: model.draft?.isEmailVerified == true ? "checkmark.seal.fill" : "envelope",
                        contentType: .emailAddress, keyboard: .emailAddress, onSubmit: { focus = .handle }
                    )
                    if model.draft?.isEmailVerified == false {
                        Text("email_not_verified_msg")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.error)
                            .padding(.horizontal, 12)
                    }
                }

                AuthTextField(
                    label: "handle", placeholder: String(localized: "handle"),
                    text: draft.handle, focus: $focus, field: .handle, systemImage: "at",
                    contentType: .username, onSubmit: { focus = .about }
                )

                aboutField

                AuthTextField(
                    label: "location", placeholder: String(localized: "location"),
                    text: optional(draft.location), focus: $focus, field: .location,
                    systemImage: "mappin.and.ellipse", contentType: .addressCity, submitLabel: .done
                )

                birthDateField

                socialLinks

                PrimaryButton(title: "save", isLoading: model.isSaving) {
                    focus = nil
                    Task { await model.save() }
                }
                .disabled(!model.hasChanges)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap($focus)
    }

    // MARK: - Sections

    private var avatar: some View {
        Button { isChoosingAvatarAction = true } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = model.pickedImage {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else if model.hasAvatar {
                        AsyncImage(url: AppEnvironment.imageURL(model.draft?.avatarImg)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AppColors.outline
                            }
                        }
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.outline.opacity(0.6))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay { Circle().stroke(AppColors.surface, lineWidth: 4) }

                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.primary, in: Circle())
                    .overlay { Circle().stroke(AppColors.surface, lineWidth: 2) }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("change_avatar"))
    }

    private var aboutField: some View {
        let about = optional(draft.about)
        return VStack(alignment: .leading, spacing: 8) {
            Text("about")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)
            TextField(
                "",
                text: limited(about, to: EditProfileViewModel.maxAboutLength),
                prompt: Text("tell_us_about_yourself").foregroundStyle(AppPalette.appLightGray),
                axis: .vertical
            )
            .lineLimit(4...10)
            .focused($focus, equals: .about)
            .foregroundStyle(AppColors.onSurface)
            .padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(focus == .about ? AppColors.primary : AppColors.outline, lineWidth: focus == .about ? 2 : 1)
            }
            Text(verbatim: "\(about.wrappedValue.count)/\(EditProfileViewModel.maxAboutLength)")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var birthDateField: some View {
        if model.canEditBirthDate {
            DateField(
                label: "birthday",
                date: $model.birthDate,
                range: Self.birthDateRange,
                initialDate: Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("birthday")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.onSurface)
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill").foregroundStyle(AppPalette.appLightGray).frame(width: 22)
                    Text(Formatters.mediumDate(model.draft?.birthDate))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(AppColors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline) }
                Text("birthday_change_lock_info")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
        }
    }

    private var socialLinks: some View {
        DisclosureGroup(isExpanded: $isSocialExpanded) {
            VStack(spacing: 12) {
                ForEach(SocialPlatform.allCases) { platform in
                    socialField(platform)
                }
            }
            .padding(.top, 12)
        } label: {
            Text("social_links")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)
        }
        .tint(AppColors.onSurface)
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline) }
    }

    private func socialField(_ platform: SocialPlatform) -> some View {
        let text = Binding(
            get: { model.draft?.socialLinks?[keyPath: platform.keyPath] ?? "" },
            set: { value in
                var links = model.draft?.socialLinks ?? SocialLinks()
                links[keyPath: platform.keyPath] = value
                model.draft?.socialLinks = links
            }
        )
        return HStack(spacing: 12) {
            platform.icon
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(focus == .social(platform) ? AppColors.primary : AppColors.onSurfaceVariant)
            TextField("", text: text, prompt: Text(platform.title).foregroundStyle(AppPalette.appLightGray))
                .focused($focus, equals: .social(platform))
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(AppColors.onSurface)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppColors.background, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func loadPickedPhoto() async {
        guard let photoItem else { return }
        defer { self.photoItem = nil }
        if let data = try? await photoItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            model.setPickedImage(image)
        } else {
            model.errorMessage = String(localized: "the_image_could_not_be_processed")
        }
    }

    /// A cleared field stays "" rather than nil: the backend clears blank values and ignores nil ones.
    private func optional(_ binding: Binding<String?>) -> Binding<String> {
        Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0 })
    }

    private func limited(_ binding: Binding<String>, to maxLength: Int) -> Binding<String> {
        Binding(get: { binding.wrappedValue }, set: { binding.wrappedValue = String($0.prefix(maxLength)) })
    }

    private static let birthDateRange: ClosedRange<Date> = {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 1920, month: 1, day: 1)) ?? .distantPast
        return start...Date()
    }()
}
