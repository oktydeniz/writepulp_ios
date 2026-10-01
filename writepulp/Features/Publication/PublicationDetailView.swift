//
//  PublicationDetailView.swift
//  writepulp
//

import SwiftUI

@MainActor
struct PublicationDetailView: View {
    let collectionsService: CollectionsService
    let onOpen: (MainRoute) -> Void
    let onSignIn: () -> Void

    @State private var model: PublicationDetailViewModel
    @State private var isPickingCollections = false
    @State private var isConfirmingPurchase = false
    @State private var isShowingCover = false
    @State private var signInMessage: LocalizedStringKey?

    init(
        publicationId: String,
        service: PublicationService,
        collectionsService: CollectionsService,
        onOpen: @escaping (MainRoute) -> Void,
        onSignIn: @escaping () -> Void
    ) {
        self.collectionsService = collectionsService
        self.onOpen = onOpen
        self.onSignIn = onSignIn
        _model = State(initialValue: PublicationDetailViewModel(publicationId: publicationId, service: service))
    }

    var body: some View {
        Group {
            if let publication = model.publication {
                content(publication)
            } else if let error = model.errorMessage, !model.isLoading {
                ErrorStateView(message: error) { Task { await model.load() } }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { toolbar }
        .toast($model.toastMessage)
        .task {
            model.reviews.onChange = { await model.load() }
            if model.publication == nil { await model.load() }
        }
        .sheet(isPresented: $isPickingCollections) {
            if let publication = model.publication {
                CollectionPickerSheet(
                    publicationId: publication.uuid,
                    initialIds: Set(publication.collections.map(\.uuid)),
                    service: collectionsService,
                    onSaved: { await model.load() },
                    onManage: { onOpen(.collections) }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingCover) {
            ImageViewer(imagePath: model.publication?.coverImg)
        }
        .alert("content_detail_buy_confirm_title", isPresented: $isConfirmingPurchase) {
            Button("cancel", role: .cancel) {}
            Button("content_detail_buy") { Task { await model.addToLibrary() } }
        } message: {
            Text("content_detail_buy_confirm_message".localized(model.publication?.priceCoin ?? 0))
        }
        .alert("sign_in", isPresented: Binding(
            get: { signInMessage != nil },
            set: { if !$0 { signInMessage = nil } }
        )) {
            Button("cancel", role: .cancel) {}
            Button("sign_in", action: onSignIn)
        } message: {
            if let signInMessage { Text(signInMessage) }
        }
    }

    // MARK: - Layout

    private func content(_ publication: PublicationDetail) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                PublicationHero(
                    publication: publication,
                    onAuthorTap: { onOpen(.profile(userId: publication.author.uuid)) },
                    onCoverTap: { isShowingCover = true }
                )

                VStack(spacing: 16) {
                    PublicationStatsView(publication: publication)
                    primaryAction(publication)
                }
                .padding(.horizontal, 16)

                if model.tabs.count > 1 {
                    Picker("content_detail", selection: $model.tab) {
                        ForEach(model.tabs, id: \.self) { tab in
                            tabTitle(tab, publication: publication).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }

                tabContent(publication)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .refreshable { await model.load() }
    }

    private func primaryAction(_ publication: PublicationDetail) -> some View {
        Button { primaryTapped(publication) } label: {
            HStack(spacing: 8) {
                if model.isAddingToLibrary {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: primaryIcon(publication))
                    Text(primaryTitle(publication))
                }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppPalette.primaryColor, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppPalette.primaryColor.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(model.isAddingToLibrary)
    }

    @ViewBuilder
    private func tabContent(_ publication: PublicationDetail) -> some View {
        switch model.tab {
        case .overview:
            PublicationOverview(publication: publication, onOpen: onOpen)
        case .chapters:
            PublicationChapterList(
                publication: publication,
                sections: model.sections.items,
                isLoadingMore: model.isLoadingSections,
                onOpen: { section in requireSignIn("content_detail_login_to_read") { openReader(chapterId: section.id) } },
                onLoadMore: { Task { await model.loadMoreSections() } }
            )
        case .reviews:
            ReviewsSection(
                model: model.reviews,
                reviewAverage: publication.reviewAverage ?? 0,
                reviewCount: publication.reviewCount,
                isOwner: publication.isOwner,
                onSignIn: onSignIn,
                onOpenProfile: { onOpen(.profile(userId: $0)) }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let publication = model.publication {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: AppLinks.publication(publication.uuid), subject: Text(publication.title)) {
                    toolbarIcon("square.and.arrow.up")
                }
                .accessibilityLabel(Text("article_share"))
                if !publication.isOwner {
                    Button {
                        requireSignIn("content_detail_login_to_bookmark") { isPickingCollections = true }
                    } label: {
                        toolbarIcon(publication.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(Text("content_detail_add_to_collection"))
                }
            }
        }
    }

    private func toolbarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.onBackground)
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
    }

    // MARK: - Actions

    private func primaryTapped(_ publication: PublicationDetail) {
        if publication.hasAccess {
            requireSignIn("content_detail_login_to_read") {
                openReader(chapterId: publication.isSinglePage ? nil : model.startChapterId)
            }
        } else {
            requireSignIn("content_detail_login_to_add_library") {
                if publication.priceCoin > 0 {
                    isConfirmingPurchase = true
                } else {
                    Task { await model.addToLibrary() }
                }
            }
        }
    }

    private func openReader(chapterId: String?) {
        onOpen(.reader(publicationId: model.publicationId, chapterId: chapterId))
    }

    private func requireSignIn(_ message: LocalizedStringKey, _ action: () -> Void) {
        if model.isSignedIn {
            action()
        } else {
            signInMessage = message
        }
    }

    private func primaryTitle(_ publication: PublicationDetail) -> String {
        if publication.isOwner { return String(localized: "content_detail_manage") }
        if publication.hasAccess { return String(localized: "content_detail_read_now") }
        if publication.priceCoin > 0 { return "content_detail_buy_for_coin".localized(publication.priceCoin) }
        return String(localized: "content_detail_add_to_library")
    }

    private func primaryIcon(_ publication: PublicationDetail) -> String {
        if publication.isOwner { return "slider.horizontal.3" }
        if publication.hasAccess { return publication.isSinglePage ? "doc.text" : "book.pages" }
        return publication.priceCoin > 0 ? "bitcoinsign.circle" : "plus"
    }

    private func tabTitle(_ tab: PublicationDetailViewModel.Tab, publication: PublicationDetail) -> Text {
        switch tab {
        case .overview: Text("content_detail_tab_overview")
        case .chapters: Text("content_detail_tab_chapters")
        case .reviews: Text("content_detail_tab_reviews".localized(publication.reviewCount))
        }
    }
}
