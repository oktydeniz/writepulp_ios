//
//  DownloadRefreshTask.swift
//  writepulp
//

import BackgroundTasks

/// Background re-download of stale copies. iOS decides when it runs (usually while the device is
/// idle); the work itself only proceeds on Wi-Fi. The foreground check in MainView is the fallback.
enum DownloadRefreshTask {
    static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.ios.writepulp") + ".downloads-refresh"
    }

    /// Must be called before the app finishes launching.
    static func register(manager: DownloadManager, network: NetworkMonitor) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            MainActor.assumeIsolated { run(task, manager: manager, network: network) }
        }
    }

    /// Replaces any pending request; 0 days (never) cancels it.
    static func schedule(autoUpdateDays days: Int) {
        guard days > 0 else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        // Fails on the simulator and when Background App Refresh is off; the foreground check covers it.
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private static func run(_ task: BGTask, manager: DownloadManager, network: NetworkMonitor) {
        schedule(autoUpdateDays: manager.autoUpdateDays)
        let work = Task {
            await network.waitUntilResolved()
            await manager.refreshStale()
        }
        task.expirationHandler = { work.cancel() }
        Task {
            await work.value
            task.setTaskCompleted(success: !work.isCancelled)
        }
    }
}
