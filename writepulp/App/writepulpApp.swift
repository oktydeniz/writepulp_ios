//
//  writepulpApp.swift
//  writepulp
//
//  Created by oktay on 27.09.2026.
//

import SwiftUI

@main
struct writepulpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var dependencies: AppDependencies

    init() {
        let dependencies = AppDependencies()
        _dependencies = State(initialValue: dependencies)
        DownloadRefreshTask.register(manager: dependencies.downloadManager, network: dependencies.networkMonitor)
        DownloadRefreshTask.schedule(autoUpdateDays: dependencies.storage.app.downloadAutoUpdateDays)
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .writePulpTheme(dependencies.storage.app)
                .localStorage(dependencies.storage)
                .environment(dependencies.networkMonitor)
        }
    }
}
