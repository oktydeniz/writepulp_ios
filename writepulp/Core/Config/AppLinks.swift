//
//  AppLinks.swift
//  writepulp
//

import Foundation

enum AppLinks {
    static let privacyPolicy = URL(string: "https://writepulp.com/privacy")!
    static let termsOfService = URL(string: "https://writepulp.com/terms")!
    static let kvkk = URL(string: "https://writepulp.com/kvkk")!
    static let aboutUs = URL(string: "https://writepulp.com/about")!
    static let contact = URL(string: "https://writepulp.com/contact")!

    static func publication(_ id: String) -> URL {
        URL(string: "https://writepulp.com/content/\(id)")!
    }
}
