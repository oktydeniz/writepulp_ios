//
//  HomeCards.swift
//  writepulp
//

import SwiftUI

struct AuthorCard: View {
    let author: AuthorFeedCard
    var width: CGFloat? = 96

    var body: some View {
        VStack(spacing: 0) {
            Avatar(imagePath: author.avatarImg, name: author.fullName, size: 72)
            Text(author.fullName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.onBackground)
                .lineLimit(1)
                .padding(.top, 6)
            if let count = author.publicationCount {
                Text("author_works_count".localized(count))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .contentShape(Rectangle())
    }
}

struct CommunityCard: View {
    let community: CommunityPreview

    var body: some View {
        VStack(spacing: 6) {
            Avatar(imagePath: community.groupAvatar, name: community.name, size: 56)
            Text(community.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)
                .lineLimit(1)
            Text("community_members_count".localized(community.memberCount ?? 0))
                .font(.system(size: 11))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 160)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

/// Section title with optional "See all", above a horizontally scrolling row.
struct HomeSectionBlock<Content: View>: View {
    let title: String
    var onSeeAll: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.onBackground)
                Spacer()
                if let onSeeAll {
                    Button("see_all", action: onSeeAll)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .frame(minHeight: 32)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }
}

struct HomeGreetingHeader: View {
    let userName: String?
    /// Guests and the limited feed get the generic greeting.
    let showsGuestGreeting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("home_greeting".localized(String(localized: timeOfDay), name))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            Text(showsGuestGreeting ? "home_greeting_sub_guest" : "home_greeting_sub")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private var name: String {
        guard !showsGuestGreeting, let userName, !userName.isEmpty else {
            return String(localized: "home_guest_name")
        }
        return userName
    }

    private var timeOfDay: String.LocalizationValue {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: "home_time_of_day_morning"
        case ..<18: "home_time_of_day_afternoon"
        default: "home_time_of_day_evening"
        }
    }
}

struct LimitedModeBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home_limited_banner_title")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.onBackground)
            Text("home_limited_banner_desc")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.onBackground.opacity(0.8))
                .padding(.top, 4)
                .padding(.bottom, 12)
            Button(action: onSignIn) {
                Text("sign_in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.primaryContainer.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
