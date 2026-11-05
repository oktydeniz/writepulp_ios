//
//  AppleReauthorizer.swift
//  writepulp
//

import AuthenticationServices
import UIKit

/// Asks Apple for a fresh authorization code, which the backend needs to revoke the account's
/// Apple tokens when it's deleted.
@MainActor
final class AppleReauthorizer: NSObject {
    enum Outcome {
        case code(String)
        case cancelled
        case failed
    }

    private var continuation: CheckedContinuation<Outcome, Never>?

    func authorize() async -> Outcome {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        // The controller only holds its delegate weakly; `self` stays alive through this call.
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private func finish(_ outcome: Outcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

extension AppleReauthorizer: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.authorizationCode,
              let code = String(data: data, encoding: .utf8)
        else { return finish(.failed) }
        finish(.code(code))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish((error as? ASAuthorizationError)?.code == .canceled ? .cancelled : .failed)
    }
}

extension AppleReauthorizer: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
