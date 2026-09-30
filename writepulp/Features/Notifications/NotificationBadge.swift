//
//  NotificationBadge.swift
//  writepulp
//

import Foundation
import Observation

/// Unread dot on the bell: polls the API every 15 s while signed in and the app is active
/// (independent of push notifications).
@MainActor
@Observable
final class NotificationBadge {
    static let pollInterval: Duration = .seconds(15)

    private(set) var unreadCount = 0
    private let service: NotificationsService

    init(service: NotificationsService) {
        self.service = service
    }

    var hasUnread: Bool { unreadCount > 0 }

    /// Runs until the calling task is cancelled (the view's `.task` ends it).
    func poll(isSignedIn: Bool) async {
        guard isSignedIn else {
            unreadCount = 0
            return
        }
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    func refresh() async {
        if let count = try? await service.unreadCount() {
            unreadCount = count
        }
    }
}
