//
//  MainTab.swift
//  writepulp
//

import SwiftUI

enum MainTab: Hashable, CaseIterable, Identifiable {
    case home
    case pocket
    case search
    case profile

    var id: Self { self }

    /// Guests only get the tabs that work without an account.
    static func tabs(isSignedIn: Bool) -> [MainTab] {
        isSignedIn ? [.home, .pocket, .search, .profile] : [.home, .search]
    }

    var title: LocalizedStringKey {
        switch self {
        case .home: "home"
        case .pocket: "pocket"
        case .search: "search"
        case .profile: "profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .pocket: "bookmark.fill"
        case .search: "magnifyingglass"
        case .profile: "person.fill"
        }
    }
}
