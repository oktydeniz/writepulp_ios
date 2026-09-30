//
//  RootView.swift
//  writepulp

import SwiftUI

enum AppRoute: Equatable {
    case splash
    case onboarding
    case auth(AuthStart)
    case main
}

@MainActor
struct RootView: View {
    let dependencies: AppDependencies

    @Environment(SessionStore.self) private var session
    @Environment(AppPreferences.self) private var preferences
    @State private var route: AppRoute = .splash

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            switch route {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.28)) { route = startRoute }
                }
                 .transition(.asymmetric(insertion: .identity,
                                        removal: .scale(scale: 0.94).combined(with: .opacity)))
            case .onboarding:
                OnboardingView(
                    onGetStarted: { finishOnboarding(then: .auth(.signUp)) },
                    onSkipOrLogin: { finishOnboarding(then: .auth(.login)) }
                )
                .transition(.opacity)
            case .auth(let start):
                AuthFlowView(start: start, authService: dependencies.authService) {
                    withAnimation(.easeInOut(duration: 0.28)) { route = .main }
                }
                .transition(.opacity)
            case .main:
                MainView(dependencies: dependencies)
                    .transition(.opacity)
            }
        }
        // Signed out from inside the app (logout, guest → login): back to login.
        // An expired session waits for the alert.
        .onChange(of: session.isLoggedIn || session.isLoggedInAsGuest) { _, isSignedIn in
            if !isSignedIn, route == .main, !session.didSessionExpire {
                withAnimation { route = .auth(.login) }
            }
        }
        .alert("session_expired_title", isPresented: .constant(session.didSessionExpire)) {
            Button("ok") {
                session.acknowledgeSessionExpired()
                withAnimation { route = .auth(.login) }
            }
        } message: {
            Text("session_expired_message")
        }
    }

    private func finishOnboarding(then next: AppRoute) {
        preferences.setFirstTimeCompleted()
        withAnimation(.easeInOut(duration: 0.28)) { route = next }
    }

    // TODO: offline launch → downloads, once that screen exists.
    private var startRoute: AppRoute {
        if preferences.isFirstTime { return .onboarding }
        if session.isLoggedIn || session.isLoggedInAsGuest { return .main }
        return .auth(.login)
    }
}

#Preview {
    let dependencies = AppDependencies()
    return RootView(dependencies: dependencies)
        .writePulpTheme(dependencies.storage.app)
        .localStorage(dependencies.storage)
}
