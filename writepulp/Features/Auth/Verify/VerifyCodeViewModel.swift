//
//  VerifyCodeViewModel.swift
//  writepulp
//

import Foundation
import Observation

@MainActor
@Observable
final class VerifyCodeViewModel {
    static let maxResends = 2
    static let resendCooldown = 60

    let email: String
    let purpose: VerifyPurpose
    var code = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var resendCount = 0
    private(set) var secondsUntilResend = 0

    private let authService: AuthService
    private var countdown: Task<Void, Never>?

    init(email: String, purpose: VerifyPurpose, authService: AuthService) {
        self.email = email
        self.purpose = purpose
        self.authService = authService
    }

    var isResendLimitReached: Bool { resendCount >= Self.maxResends }
    var canResend: Bool { !isResendLimitReached && secondsUntilResend == 0 }

    func verify() async -> Bool {
        if let error = FormValidator.otp(code) {
            errorMessage = error
            return false
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.verifyCode(email: email, code: code, purpose: purpose)
            return true
        } catch APIError.cancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resend() async {
        guard canResend else { return }
        code = ""
        errorMessage = nil
        resendCount += 1
        startCountdown()
        do {
            try await authService.resendCode(email: email, purpose: purpose)
        } catch APIError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func stopCountdown() {
        countdown?.cancel()
    }

    private func startCountdown() {
        countdown?.cancel()
        secondsUntilResend = Self.resendCooldown
        countdown = Task { [weak self] in
            while let self, self.secondsUntilResend > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.secondsUntilResend -= 1
            }
        }
    }
}
