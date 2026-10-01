//
//  ProfileAboutView.swift
//  writepulp
//

import SwiftUI

/// Join date, location, bio and social links.
struct ProfileAboutView: View {
    let profile: UserProfile

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let joined = joinedText {
                    Text(joined)
                }
                Spacer()
                if let location = profile.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(AppColors.onSurfaceVariant)

            Text(bio)
                .appTextStyle(.bodyLarge)
                .foregroundStyle(AppColors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("social_links")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .padding(.top, 4)
            Divider()

            if let links = profile.socialLinks, !links.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(SocialPlatform.allCases) { platform in
                        if let value = links[keyPath: platform.keyPath], let url = SocialPlatform.url(from: value) {
                            Button { openURL(url) } label: { chip(platform) }
                                .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var bio: String {
        if let about = profile.about, !about.isEmpty { return about }
        return profile.isMe
            ? String(localized: "you_haven_t_added_a_bio_yet")
            : String(localized: "this_user_hasn_t_shared_their_story_yet")
    }

    private var joinedText: String? {
        guard let date = Formatters.date(fromISO: profile.createdAt) else { return nil }
        return "joined_date".localized(date.formatted(.dateTime.month(.wide).year()))
    }

    private func chip(_ platform: SocialPlatform) -> some View {
        HStack(spacing: 6) {
            platform.icon
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text(platform.title)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(AppColors.onSurface)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.outline.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppColors.primary) }
    }
}
