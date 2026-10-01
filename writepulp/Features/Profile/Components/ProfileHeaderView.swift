//
//  ProfileHeaderView.swift
//  writepulp
//

import SwiftUI

/// Cover image with the avatar, name, handle and badges.
struct ProfileHeaderView: View {
    let profile: UserProfile
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Image("ProfileHeaderBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
                    .frame(maxHeight: .infinity, alignment: .top)

                Button(action: onAvatarTap) {
                    Avatar(imagePath: profile.avatarImg, name: profile.fullName, size: 110)
                        .overlay { Circle().stroke(AppColors.surface, lineWidth: 4) }
                }
                .buttonStyle(.plain)
                .disabled(profile.avatarImg?.isEmpty ?? true)
                .accessibilityLabel(Text("avatar"))
            }
            .frame(height: 260)

            HStack(spacing: 4) {
                Text(profile.fullName)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(AppColors.onSurface)
                if profile.approvedAccount {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppPalette.primaryColor)
                        .accessibilityLabel(Text("profile_approved_account"))
                }
                if let emoji = profile.badgeEmoji {
                    Text(emoji).font(.system(size: 18))
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .multilineTextAlignment(.center)

            Text(verbatim: "@\(profile.handle)")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.8))
        }
    }
}

/// Works / followers / following counts; the follow counts open the lists when visible.
struct ProfileStatsView: View {
    let profile: UserProfile
    let onOpenFollows: (FollowListKind) -> Void

    var body: some View {
        HStack(spacing: 0) {
            stat("tab_works", value: profile.worksCount)
            Divider().frame(height: 30)
            stat("followers", value: profile.followerCount, kind: .followers)
            Divider().frame(height: 30)
            stat("following", value: profile.followingCount, kind: .following)
        }
        .padding(.vertical, 16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline) }
    }

    @ViewBuilder
    private func stat(_ label: LocalizedStringKey, value: Int, kind: FollowListKind? = nil) -> some View {
        let content = VStack(spacing: 2) {
            Text(Formatters.compactCount(value))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)

        if let kind, profile.isContentVisible, value > 0 {
            Button { onOpenFollows(kind) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(PressableButtonStyle())
        } else {
            content
        }
    }
}

/// Segmented About / Works / Lists selector.
struct ProfileTabBar: View {
    @Binding var selection: ProfileViewModel.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileViewModel.Tab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
                } label: {
                    Text(title(tab))
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? AppColors.primary : AppColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 20).fill(AppColors.surface)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppColors.outline.opacity(0.5), in: RoundedRectangle(cornerRadius: 24))
    }

    private func title(_ tab: ProfileViewModel.Tab) -> LocalizedStringKey {
        switch tab {
        case .about: "tab_about"
        case .works: "tab_works"
        case .lists: "tab_lists"
        }
    }
}

struct PrivateAccountPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34))
                .foregroundStyle(AppColors.primary.opacity(0.6))
                .frame(width: 80, height: 80)
                .background(AppColors.primary.opacity(0.1), in: Circle())
                .padding(.bottom, 4)
            Text("this_account_is_private")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
            Text("private_account_description")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}
