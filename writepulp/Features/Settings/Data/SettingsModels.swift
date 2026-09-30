//
//  SettingsModels.swift
//  writepulp
//

import SwiftUI

/// `data` of GET settings. Languages stay as backend codes ("en", "tr") and are sent back unchanged.
struct UserSettings: Codable, Equatable {
    var showAgeRestricted: Bool
    var pushNewChapter: Bool
    var pushCommunityReply: Bool
    var pushPromotions: Bool
    var pushCoinRewards: Bool
    var lang: String
    var appThemeDark: Bool
    var enable2FA: Bool
    var currencyPreference: Currency
    var isMessageActive: Bool
    var isPrivateAccount: Bool
    var saveReadingHistory: Bool
    var followersAndRequest: Bool
    var userRecommendations: Bool
    var weeklyMonthlyLists: Bool
    var categoryPreferences: Set<String>
    var isHiddenAccount: Bool
    var isMailVerified: Bool
    var email: String
    var languagePreferences: [String]
    var showInspirationQuote: Bool
    var gender: Gender?
    var shareDemographicData: Bool

    static let maxCategories = 8

    enum Currency: String, Codable, CaseIterable {
        case none = "NONE", usd = "USD", eur = "EUR", `try` = "TRY"

        static let selectable: [Currency] = [.usd, .eur, .try]

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Currency(rawValue: raw) ?? .none
        }

        var label: LocalizedStringKey {
            switch self {
            case .usd: "settings_currency_usd"
            case .eur: "settings_currency_eur"
            case .try: "settings_currency_try"
            case .none: "settings_gender_not_set"
            }
        }
    }

    enum Gender: String, Codable, CaseIterable {
        case man = "MAN", woman = "WOMAN", nonBinary = "NON_BINARY", other = "OTHER", preferNotToSay = "PREFER_NOT_TO_SAY"

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Gender(rawValue: raw) ?? .other
        }

        var label: LocalizedStringKey {
            switch self {
            case .man: "settings_gender_man"
            case .woman: "settings_gender_woman"
            case .nonBinary: "settings_gender_non_binary"
            case .other: "settings_gender_other"
            case .preferNotToSay: "settings_gender_prefer_not_say"
            }
        }
    }

    /// The seven notification switches, toggled together by "control all".
    var allNotificationsOn: Bool {
        pushNewChapter && pushCommunityReply && pushCoinRewards && pushPromotions
            && followersAndRequest && userRecommendations && weeklyMonthlyLists
    }

    mutating func setAllNotifications(_ on: Bool) {
        pushNewChapter = on
        pushCommunityReply = on
        pushCoinRewards = on
        pushPromotions = on
        followersAndRequest = on
        userRecommendations = on
        weeklyMonthlyLists = on
    }
}

/// Body of PUT settings: everything except the email fields, which have their own endpoint.
struct UserSettingsUpdate: Encodable {
    let settings: UserSettings

    private enum CodingKeys: String, CodingKey {
        case showAgeRestricted, pushNewChapter, pushCommunityReply, pushPromotions, pushCoinRewards, lang,
             appThemeDark, enable2FA, currencyPreference, isMessageActive, isPrivateAccount, saveReadingHistory,
             followersAndRequest, userRecommendations, weeklyMonthlyLists, categoryPreferences, isHiddenAccount,
             languagePreferences, showInspirationQuote, gender, shareDemographicData
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(settings.showAgeRestricted, forKey: .showAgeRestricted)
        try c.encode(settings.pushNewChapter, forKey: .pushNewChapter)
        try c.encode(settings.pushCommunityReply, forKey: .pushCommunityReply)
        try c.encode(settings.pushPromotions, forKey: .pushPromotions)
        try c.encode(settings.pushCoinRewards, forKey: .pushCoinRewards)
        try c.encode(settings.lang, forKey: .lang)
        try c.encode(settings.appThemeDark, forKey: .appThemeDark)
        try c.encode(settings.enable2FA, forKey: .enable2FA)
        try c.encode(settings.currencyPreference, forKey: .currencyPreference)
        try c.encode(settings.isMessageActive, forKey: .isMessageActive)
        try c.encode(settings.isPrivateAccount, forKey: .isPrivateAccount)
        try c.encode(settings.saveReadingHistory, forKey: .saveReadingHistory)
        try c.encode(settings.followersAndRequest, forKey: .followersAndRequest)
        try c.encode(settings.userRecommendations, forKey: .userRecommendations)
        try c.encode(settings.weeklyMonthlyLists, forKey: .weeklyMonthlyLists)
        try c.encode(settings.categoryPreferences.sorted(), forKey: .categoryPreferences)
        try c.encode(settings.isHiddenAccount, forKey: .isHiddenAccount)
        try c.encode(settings.languagePreferences, forKey: .languagePreferences)
        try c.encode(settings.showInspirationQuote, forKey: .showInspirationQuote)
        try c.encodeIfPresent(settings.gender, forKey: .gender)
        try c.encode(settings.shareDemographicData, forKey: .shareDemographicData)
    }
}

struct CategoryGroup: Decodable, Identifiable {
    struct Category: Decodable, Identifiable {
        let id: String?
        let name: String

        var identity: String { id ?? name }
    }

    let parent: Category
    let subCategories: [Category]

    var id: String { parent.identity }
}
