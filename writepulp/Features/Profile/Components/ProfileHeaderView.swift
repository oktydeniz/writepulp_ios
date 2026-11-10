//
//  ProfileHeaderView.swift
//  writepulp
//

import SwiftUI

/// Profile cover images. Users cannot pick one yet, so each profile gets one derived from its uuid:
/// looks random across users, but stays the same for a user on every visit and on web, Android and
/// iOS (same order and rule as Android `ProfileCover.kt` and web `profileCover.ts`). When covers
/// become selectable, the user's choice wins and this stays as the fallback.
enum ProfileCover {
    static let assetNames = [
        "ProfileCoverNight", "ProfileCoverDawn", "ProfileCoverPaper", "ProfileCoverCommunity", "ProfileCoverGold",
    ]

    /// Last 8 hex digits of the uuid, modulo the number of covers.
    static func index(for uuid: String) -> Int {
        let hex = String(uuid.lowercased().filter { $0.isHexDigit }.suffix(8))
        let value = UInt64(hex, radix: 16) ?? 0
        return Int(value % UInt64(assetNames.count))
    }

    static func assetName(for uuid: String) -> String { assetNames[index(for: uuid)] }
}

/// Cover image with the avatar, name, handle and badges.
struct ProfileHeaderView: View {
    let profile: UserProfile
    let onAvatarTap: () -> Void

    private let avatarSize: CGFloat = 110

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                // 2:1 cover; the avatar hangs half over its bottom edge.
                Color.clear
                    .aspectRatio(2, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Image(ProfileCover.assetName(for: profile.uuid))
                            .resizable()
                            .scaledToFill()
                    }
                    .overlay(alignment: .top) {
                        // Keeps the back / menu buttons readable on light covers.
                        LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 72)
                    }
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                    .padding(.bottom, avatarSize / 2)

                Button(action: onAvatarTap) {
                    Avatar(imagePath: profile.avatarImg, name: profile.fullName, size: avatarSize)
                        .overlay { Circle().stroke(AppColors.surface, lineWidth: 4) }
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(profile.avatarImg?.isEmpty ?? true)
                .accessibilityLabel(Text("avatar"))
            }

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

/// What a blocked user's profile shows instead of its header and content, matching Android.
struct BlockedProfileView: View {
    let name: String
    let onUnblock: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "nosign")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(AppColors.primary.opacity(0.6))
                .padding(.bottom, 12)
            Text(verbatim: name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text("blocked_profile_title")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)
            Text("blocked_profile_message")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            Button(action: onUnblock) {
                Text("unblock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .overlay(Capsule().stroke(AppColors.onSurface.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 16)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
