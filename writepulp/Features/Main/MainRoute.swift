//
//  MainRoute.swift
//  writepulp
//

import Foundation

/// Screens pushed inside a tab's navigation stack. Any tab, the side menu and notifications can open them.
enum MainRoute: Hashable {
    case publication(id: String)
    case profile(userId: String)
    case community(id: String, name: String)
    case collection(id: String, name: String)
    case homeSection(key: String, title: String, type: PublicationType?)
    case authorsOfTheWeek
    case notifications
    case editProfile
    case collections
    case groups
    case downloads
    case wallet
    case settings
}
