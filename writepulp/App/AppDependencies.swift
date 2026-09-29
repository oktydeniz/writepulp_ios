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

    init(storage: LocalStorage = LocalStorage()) {
        self.storage = storage
        apiClient = APIClient(
            baseURL: AppEnvironment.apiBaseURL,
            tokenStore: storage.session,
            languageCode: { AppPreferences.currentLanguageCode },
            logger: AppEnvironment.isDevMode ? NetworkLogger() : nil
        )
        authService = AuthService(api: apiClient, session: storage.session, preferences: storage.app)
    }
}
