//
//  PushNotifications.swift
//  writepulp
//

import FirebaseMessaging
import Observation
import UIKit
import UserNotifications

/// Push permission, the FCM token's registration with the backend, and taps waiting to be opened.
/// Shared because UIKit callbacks (AppDelegate) arrive before and outside the SwiftUI tree.
///
/// Remote pushes need the Push Notifications capability (paid Apple Developer account). Without it
/// no APNs/FCM token ever arrives, so token registration is simply skipped.
@MainActor
@Observable
final class PushNotifications {
    static let shared = PushNotifications()

    /// A tapped push waiting for the signed-in shell to open it.
    private(set) var pendingPayload: PushPayload?

    private var fcmToken: String?
    private var api: APIClient?
    private var session: SessionStore?

    private init() {}

    func configure(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    // MARK: - Permission

    /// Asks once (iOS remembers the answer) and registers with APNs when allowed.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    // MARK: - Token

    func tokenDidChange(_ token: String?) {
        fcmToken = token
        Task { await registerToken() }
    }

    /// Sends the current FCM token to the backend when signed in (after login/register, and on refresh).
    func registerToken() async {
        guard let api, let session, session.isLoggedIn else { return }
        let token: String
        if let fcmToken {
            token = fcmToken
        } else if let fetched = try? await Messaging.messaging().token() {
            token = fetched
        } else {
            return
        }
        if (try? await api.send(NotificationsAPI.registerDevice(token: token))) != nil {
            session.saveDeviceToken(token)
        }
    }

    /// Called on logout, before the session is cleared.
    func unregisterToken() async {
        guard let api, let token = session?.deviceToken, !token.isEmpty else { return }
        _ = try? await api.send(NotificationsAPI.unregisterDevice(token: token))
    }

    /// Session expired: the backend row can't be removed without a valid session, so the FCM token
    /// is dropped instead. The next push to it fails as unregistered and the backend prunes it.
    func forgetToken() async {
        fcmToken = nil
        try? await Messaging.messaging().deleteToken()
    }

    // MARK: - Taps

    func didTap(userInfo: [AnyHashable: Any]) {
        guard let payload = PushPayload(userInfo: userInfo) else { return }
        pendingPayload = payload
    }

    func consumePending() -> PushPayload? {
        defer { pendingPayload = nil }
        return pendingPayload
    }
}
