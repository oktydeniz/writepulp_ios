//
//  AppLinks.swift
//  writepulp
//

import Foundation

enum AppLinks {
    static let privacyPolicy = URL(string: "https://writepulp.com/privacy")!
    static let termsOfService = URL(string: "https://writepulp.com/terms")!
    static let aboutUs = URL(string: "https://writepulp.com/about")!

    static func publication(_ id: String) -> URL {
        URL(string: "https://writepulp.com/content/\(id)")!
    }
}
