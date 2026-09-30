//
//  HomeView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct HomeView: View {
    let onOpen: (MainRoute) -> Void
    let onSignIn: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var model: HomeViewModel

    init(
        service: HomeService,
        preferences: AppPreferences,
        onOpen: @escaping (MainRoute) -> Void,
        onSignIn: @escaping () -> Void
    ) {
        self.onOpen = onOpen
        self.onSignIn = onSignIn
        _model = State(initialValue: HomeViewModel(service: service, preferences: preferences))
    }

    var body: some View {
        Group {
            if let feed = model.feed {
                content(feed)
            } else if let error = model.errorMessage {
                errorState(error)
            } else {
                HomeSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .task { await model.loadIfNeeded() }
    }

    private func content(_ feed: HomeFeed) -> some View {
        let isSignedIn = session.isLoggedIn
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HomeGreetingHeader(
                    userName: session.fullName,
                    showsGuestGreeting: !isSignedIn || feed.mode == .limited
                )

                if feed.mode == .limited {
                    LimitedModeBanner(onSignIn: onSignIn)
                }

                if isSignedIn, model.showsInspiration {
                    InspirationBoxCard(index: model.inspirationIndex) {
                        withAnimation { model.dismissInspiration() }
                    }
                    .padding(.horizontal, 16)
                }

                if isSignedIn, !feed.continueReading.isEmpty {
                    HomeSectionBlock(title: String(localized: "home_continue_reading")) {
                        publicationCards(feed.continueReading)
                    }
                }

                ForEach(feed.sections.filter { !$0.items.isEmpty }) { section in
                    HomeSectionBlock(title: section.displayTitle) {
                        onOpen(.homeSection(key: section.key, title: section.displayTitle, type: feed.typeFilter))
                    } content: {
                        publicationCards(section.items)
                    }
                }

                if !feed.authorsOfTheWeek.isEmpty {
                    HomeSectionBlock(title: String(localized: "home_authors_of_week")) {
                        onOpen(.authorsOfTheWeek)
                    } content: {
                        ForEach(feed.authorsOfTheWeek) { author in
                            Button { onOpen(.profile(userId: author.id)) } label: { AuthorCard(author: author) }
                                .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                if !model.communities.isEmpty {
                    HomeSectionBlock(title: String(localized: "home_popular_communities")) {
                        ForEach(model.communities) { community in
                            Button {
                                onOpen(.community(id: community.uuid, name: community.name))
                            } label: {
                                CommunityCard(community: community)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .refreshable { await model.load() }
    }

    private func publicationCards(_ cards: [PublicationFeedCard]) -> some View {
        ForEach(cards) { card in
            Button { onOpen(.publication(id: card.id)) } label: {
                PublicationCard(content: card.cardContent).frame(width: 180)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.error)
                .multilineTextAlignment(.center)
            TextLinkButton(title: "retry", color: AppColors.primary) {
                Task { await model.load() }
            }
        }
        .padding(24)
    }
}

/// Placeholder rows while the first feed loads.
private struct HomeSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4).frame(width: 140, height: 18).padding(.horizontal, 16)
                        HStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12).frame(width: 180, height: 250)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 20)
            .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.15))
        }
        .scrollDisabled(true)
        .accessibilityHidden(true)
    }
}
