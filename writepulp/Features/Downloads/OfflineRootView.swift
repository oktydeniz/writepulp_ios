//
//  OfflineRootView.swift
//  writepulp
//

import SwiftUI

/// Shown when the app starts without a connection: only downloaded content and its readers.
@MainActor
struct OfflineRootView: View {
    let dependencies: AppDependencies
    let onReconnect: () -> Void

    @Environment(AppPreferences.self) private var preferences
    @State private var path: [MainRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            DownloadsView(
                manager: dependencies.downloadManager,
                network: dependencies.networkMonitor,
                preferences: preferences,
                isOffline: true,
                onOpen: { path.append($0) },
                onReconnect: onReconnect
            )
            .navigationDestination(for: MainRoute.self) { route in
                if case .reader(let publicationId, let type, let chapterId) = route {
                    ReaderScreen(
                        publicationId: publicationId,
                        type: type,
                        chapterId: chapterId,
                        service: dependencies.readerService
                    )
                }
            }
        }
    }
}
