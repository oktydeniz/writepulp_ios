//
//  SignUpViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class SignUpViewModel {
    var fullName = ""
    var email = "" {
        didSet { suggestHandle(previousEmail: oldValue) }
    }
    var handle = ""
    var password = ""
    var passwordConfirmation = ""
    var birthDate: Date?
    var acceptsTerms = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    /// Wheel start for the birthday picker, and its allowed range.
    let birthDateInitial = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    let birthDateRange: ClosedRange<Date> = {
        let start = DateComponents(calendar: Calendar(identifier: .gregorian), year: 1920, month: 1, day: 1).date ?? .distantPast
        return start...Date()
    }()

    var cleanedHandle: String {
        handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Email the code was sent to, or nil when validation or the request failed.
    func register() async -> String? {
        if let error = FormValidator.firstError(
            FormValidator.fullName(fullName),
            FormValidator.email(email),
            FormValidator.handle(cleanedHandle),
            FormValidator.password(password),
            FormValidator.passwordsMatch(password, passwordConfirmation),
            FormValidator.birthDate(birthDate),
            acceptsTerms ? nil : String(localized: "err_terms_not_accepted")
        ) {
            errorMessage = error
            return nil
        }
        guard let birthDate else { return nil }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            return try await authService.register(
                fullName: fullName,
                email: email,
                handle: cleanedHandle,
                password: password,
                passwordConfirmation: passwordConfirmation,
                birthDate: birthDate
            )
        } catch APIError.cancelled {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Fills the handle from the email's local part until the user types their own.
    private func suggestHandle(previousEmail: String) {
        let previousSuggestion = String(previousEmail.split(separator: "@", omittingEmptySubsequences: false).first ?? "")
        guard handle.isEmpty || handle == previousSuggestion else { return }
        handle = String(email.split(separator: "@", omittingEmptySubsequences: false).first ?? "")
    }
}
