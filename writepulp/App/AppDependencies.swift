//
//  AppDependencies.swift
//  writepulp
//

import Foundation

/// Composition root: shared services are created here once and handed to features.
final class AppDependencies {
    let storage: LocalStorage
    let apiClient: APIClient
    let authService: AuthService
    let homeService: HomeService
    let notificationsService: NotificationsService
    let settingsService: SettingsService
    let walletService: WalletService
    let profileService: ProfileService
    let collectionsService: CollectionsService
    let searchService: SearchService
    let pocketService: PocketService
    let publicationService: PublicationService
    let readerService: ReaderService
    let networkMonitor: NetworkMonitor
    let downloadManager: DownloadManager

    init(storage: LocalStorage = LocalStorage()) {
        self.storage = storage
        apiClient = APIClient(
            baseURL: AppEnvironment.apiBaseURL,
            tokenStore: storage.session,
            languageCode: { AppPreferences.currentLanguageCode },
            logger: AppEnvironment.isDevMode ? NetworkLogger() : nil
        )
        authService = AuthService(api: apiClient, session: storage.session, preferences: storage.app)
        homeService = HomeService(api: apiClient)
        notificationsService = NotificationsService(api: apiClient)
        settingsService = SettingsService(api: apiClient, session: storage.session)
        walletService = WalletService(api: apiClient)
        profileService = ProfileService(api: apiClient, session: storage.session)
        collectionsService = CollectionsService(api: apiClient)
        searchService = SearchService(api: apiClient, session: storage.session)
        pocketService = PocketService(api: apiClient)
        publicationService = PublicationService(api: apiClient, session: storage.session)
        let downloadStore = DownloadStore()
        networkMonitor = NetworkMonitor()
        readerService = ReaderService(api: apiClient, session: storage.session, offline: downloadStore)
        downloadManager = DownloadManager(
            store: downloadStore,
            api: apiClient,
            session: storage.session,
            preferences: storage.app,
            network: networkMonitor
        )
    }
}
