//
//  GroupComponents.swift
//  writepulp
//

import SwiftUI

struct GroupAvatar: View {
    let imagePath: String?
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle().fill(AppColors.primary.opacity(0.1))
            if let url = AppEnvironment.imageURL(imagePath) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.3.fill")
            .font(.system(size: size * 0.32))
            .foregroundStyle(AppColors.primary)
    }
}

struct RoleBadge: View {
    let role: GroupRole?

    var body: some View {
        Text(role.titleKey)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(role.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(role.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(role.color.opacity(0.4), lineWidth: 0.5))
    }
}

/// Categories as chips followed by #tags.
struct GroupMetaTags: View {
    let categories: [GroupCategory]
    let tags: [String]

    var body: some View {
        if !categories.isEmpty || !tags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(categories, id: \.identity) { category in
                    Text(category.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primary.opacity(0.12), in: Capsule())
                }
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.outline.opacity(0.35), in: Capsule())
                }
            }
        }
    }
}

/// Card of a group with its membership action: open (joined), withdraw (pending) or join / request.
struct GroupRow: View {
    let group: CommunityGroup
    var isProcessing = false
    let onOpen: () -> Void
    var onJoin: () -> Void = {}
    var onWithdraw: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GroupAvatar(imagePath: group.groupAvatar)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppColors.onSurface)
                                .lineLimit(1)
                            if group.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.onSurfaceVariant)
                                    .accessibilityLabel(Text("private_community"))
                            }
                        }
                        Text("community_members_count".localized(group.memberCount))
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    trailing
                }
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurface.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                GroupMetaTags(categories: group.categories, tags: group.tags)
            }
            .padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private var trailing: some View {
        if isProcessing {
            ProgressView().frame(width: 40)
        } else {
            switch group.userStatus {
            case .joined:
                HStack(spacing: 8) {
                    if group.unreadCount > 0 {
                        Text(String(group.unreadCount))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.onPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppColors.primary, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.6))
                }
            case .pending:
                FollowButton(title: "follow_requested", systemImage: "clock", isActive: true, height: 32, action: onWithdraw)
            case .none:
                FollowButton(
                    title: group.canJoinDirectly ? "join" : "request_to_join",
                    systemImage: group.canJoinDirectly ? "plus" : "paperplane",
                    height: 32,
                    action: onJoin
                )
            }
        }
    }
}
