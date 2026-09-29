//
//  String+Localized.swift
//  writepulp
//

import Foundation

extension String {
    /// For keys with placeholders: "home_greeting".localized(part, name)
    func localized(_ args: CVarArg...) -> String {
        let format = String(localized: LocalizationValue(self))
        return args.isEmpty ? format : String(format: format, locale: .current, arguments: args)
    }
}
