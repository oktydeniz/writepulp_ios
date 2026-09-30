//
//  AppDelegate.swift
//  writepulp
//

import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import UIKit
import UserNotifications

/// UIKit entry points SwiftUI doesn't cover: Firebase setup, APNs/FCM tokens and notification taps.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(AppEnvironment.isCrashReportingEnabled)

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected without the Push Notifications capability (free Apple account); nothing to register.
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in PushNotifications.shared.tokenDidChange(fcmToken) }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Show pushes as banners while the app is open too.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { PushNotifications.shared.didTap(userInfo: userInfo) }
    }
}
