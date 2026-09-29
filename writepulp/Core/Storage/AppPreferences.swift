//
//  AppPreferences.swift
//  writepulp
//

import SwiftUI
import Observation

@Observable
final class AppPreferences {
    static let defaultDownloadAutoUpdateDays = 7

    private enum Key {
        static let isFirstTime = "is_first_time"
        static let darkMode = "dark_mode_key"
        static let rememberedEmail = "remembered_email"
        static let inspirationBoxEnabled = "inspiration_box_enabled_key"
        static let inspirationBoxStartDay = "inspiration_box_start_day_key"
        static let downloadMedia = "download_media_key"
        static let downloadAutoUpdateDays = "download_auto_update_days_key"
    }

    private let defaults: UserDefaults

    private(set) var isFirstTime = true
    /// nil = follow system.
    private(set) var isDarkMode: Bool?
    private(set) var rememberedEmail: String?
    private(set) var isInspirationBoxEnabled = true
    /// Whether images inside downloaded sections are cached; covers and avatars always are.
    private(set) var isDownloadMediaEnabled = true
    /// Days between background refreshes of downloads; 0 = never.
    private(set) var downloadAutoUpdateDays = AppPreferences.defaultDownloadAutoUpdateDays

    init(defaults: UserDefaults) {
        self.defaults = defaults
        reload()
    }

    func reload() {
        isFirstTime = defaults.object(forKey: Key.isFirstTime) as? Bool ?? true
        isDarkMode = defaults.object(forKey: Key.darkMode) as? Bool
        rememberedEmail = defaults.string(forKey: Key.rememberedEmail)
        isInspirationBoxEnabled = defaults.object(forKey: Key.inspirationBoxEnabled) as? Bool ?? true
        isDownloadMediaEnabled = defaults.object(forKey: Key.downloadMedia) as? Bool ?? true
        downloadAutoUpdateDays = defaults.object(forKey: Key.downloadAutoUpdateDays) as? Int
            ?? Self.defaultDownloadAutoUpdateDays
    }

    var colorScheme: ColorScheme? {
        isDarkMode.map { $0 ? .dark : .light }
    }

    func setFirstTimeCompleted() {
        defaults.set(false, forKey: Key.isFirstTime)
        isFirstTime = false
    }

    func setDarkMode(_ isDark: Bool?) {
        defaults.set(isDark, forKey: Key.darkMode)
        isDarkMode = isDark
    }

    /// UI language code ("en"/"tr"), e.g. for Accept-Language. iOS relaunches the app on a
    /// language change, so reading it live is enough.
    var languageCode: String { Self.currentLanguageCode }

    static var currentLanguageCode: String {
        Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) } ?? "en"
    }

    func saveRememberedEmail(_ email: String) {
        defaults.set(email, forKey: Key.rememberedEmail)
        rememberedEmail = email
    }

    func clearRememberedEmail() {
        defaults.removeObject(forKey: Key.rememberedEmail)
        rememberedEmail = nil
    }

    func setInspirationBoxEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.inspirationBoxEnabled)
        isInspirationBoxEnabled = enabled
    }

    /// Stable index in [0, total) that advances by one each (UTC) day, starting from the first call.
    func inspirationBoxTodayIndex(total: Int) -> Int {
        let today = Int(Date().timeIntervalSince1970 / 86_400)
        let startDay: Int
        if let stored = defaults.object(forKey: Key.inspirationBoxStartDay) as? Int {
            startDay = stored
        } else {
            defaults.set(today, forKey: Key.inspirationBoxStartDay)
            startDay = today
        }
        let elapsed = today - startDay
        return ((elapsed % total) + total) % total
    }

    func setDownloadMediaEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.downloadMedia)
        isDownloadMediaEnabled = enabled
    }

    func setDownloadAutoUpdateDays(_ days: Int) {
        defaults.set(days, forKey: Key.downloadAutoUpdateDays)
        downloadAutoUpdateDays = days
    }
}
