//
//  GroupChatComponents.swift
//  writepulp
//

import PhotosUI
import SwiftUI

struct GroupMessageBubble: View {
    let message: GroupMessage
    let isMine: Bool
    let onImageTap: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                Avatar(imagePath: message.senderAvatar, name: message.senderName, size: 32)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    HStack(spacing: 6) {
                        Text(message.senderName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.onSurface)
                            .lineLimit(1)
                        RoleBadge(role: message.senderRole)
                    }
                    .padding(.leading, 4)
                }
                bubble
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.replyToId != nil {
                ReplyQuote(
                    senderName: message.replyToSenderName ?? "",
                    content: message.replyToContent ?? "",
                    isMine: isMine
                )
            }
            if let path = message.imageUrl, !path.isEmpty {
                AsyncImage(url: AppEnvironment.imageURL(path)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        AppColors.skeleton
                    }
                }
                .frame(width: 220, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onTapGesture { onImageTap(path) }
            }
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(isMine ? AppColors.onPrimary : AppColors.onSurface)
                    .textSelection(.enabled)
            }
            // Reserves the time's space; the overlay pins it to the trailing edge without
            // stretching the bubble to full width.
            timeLabel.hidden()
        }
        .overlay(alignment: .bottomTrailing) { timeLabel }
        .padding(10)
        .frame(minWidth: 80, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            isMine ? AppColors.primary : AppColors.surface,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: isMine ? 16 : 4,
                bottomTrailingRadius: isMine ? 4 : 16,
                topTrailingRadius: 16
            )
        )
    }

    private var timeLabel: some View {
        Text(Self.timeText(message.sentAt))
            .font(.system(size: 10))
            .foregroundStyle((isMine ? AppColors.onPrimary : AppColors.onSurface).opacity(0.65))
    }

    private static func timeText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

struct ReplyQuote: View {
    let senderName: String
    let content: String
    let isMine: Bool

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(isMine ? AppColors.onPrimary : AppColors.primary)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(senderName)
                    .font(.system(size: 11, weight: .bold))
                Text(content.isEmpty ? String(localized: "image_message") : content)
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            .foregroundStyle(isMine ? AppColors.onPrimary : AppColors.onSurface)
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .background((isMine ? Color.black.opacity(0.12) : AppColors.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// "N unread messages" divider.
struct UnreadDivider: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            line
            Text("unread_messages".localized(count))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .fixedSize()
            line
        }
        .padding(.vertical, 4)
    }

    private var line: some View {
        Rectangle().fill(AppColors.primary.opacity(0.4)).frame(height: 0.5)
    }
}

/// Input bar: reply preview, image attachment, text field and send button.
struct GroupChatComposer: View {
    @Bindable var model: GroupChatViewModel
    let onSent: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let reply = model.replyTarget {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("replying_to".localized(reply.senderName))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                            .lineLimit(1)
                        Text(reply.previewText)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { model.replyTarget = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .accessibilityLabel(Text("cancel_reply"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if let image = model.attachment {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .topTrailing) {
                            Button { model.attachment = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .padding(4)
                        }
                    Spacer()
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                }
                .disabled(!model.canSend)
                .foregroundStyle(model.canSend ? AppColors.primary : AppColors.onSurfaceVariant.opacity(0.5))

                TextField(
                    "",
                    text: $model.draft,
                    prompt: Text(model.canSend ? "write_a_message" : "restricted_messaging_desc_for_user")
                        .foregroundStyle(AppColors.onSurfaceVariant),
                    axis: .vertical
                )
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(!model.canSend)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.outline, lineWidth: 0.5))

                Button {
                    Task {
                        await model.send()
                        onSent()
                    }
                } label: {
                    Group {
                        if model.isSending {
                            ProgressView().tint(AppColors.onPrimary)
                        } else {
                            Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(model.canSubmit ? AppColors.primary : AppColors.onSurfaceVariant.opacity(0.35), in: Circle())
                }
                .disabled(!model.canSubmit)
                .accessibilityLabel(Text("send"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.background)
        .overlay(alignment: .top) { Divider() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.attachment = image
                }
                photoItem = nil
            }
        }
    }
}

struct GroupRulesSheet: View {
    let rules: [String]

    var body: some View {
        NavigationStack {
            Group {
                if rules.isEmpty {
                    EmptyStateView(systemImage: "list.bullet.rectangle", title: "no_rules_yet")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.onPrimary)
                                        .frame(width: 26, height: 26)
                                        .background(AppColors.primary, in: Circle())
                                    Text(rule)
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppColors.onSurface)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("community_rules")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Alternating placeholder bubbles while the first page loads.
struct ChatSkeleton: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<7, id: \.self) { index in
                let isMine = index % 3 == 1
                HStack(alignment: .bottom, spacing: 8) {
                    if isMine { Spacer() } else { SkeletonBlock(width: 32, height: 32, cornerRadius: 16) }
                    SkeletonBlock(width: CGFloat([180, 140, 220, 120][index % 4]), height: CGFloat(index % 2 == 0 ? 44 : 64), cornerRadius: 16)
                    if !isMine { Spacer() }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .shimmering()
    }
}
