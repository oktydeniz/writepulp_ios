//
//  OnboardingView.swift
//  writepulp
//

import SwiftUI

private struct OnboardingPage: Identifiable {
    let id: Int
    let image: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    static let all: [OnboardingPage] = (1...5).map { index in
    
        let titleKey = "ob_title_\(index)"
        let descriptionKey = "ob_desc_\(index)"
        return OnboardingPage(
            id: index - 1,
            image: "Onboarding\(index)",
            title: LocalizedStringKey(titleKey),
            description: LocalizedStringKey(descriptionKey)
        )
    }
}

struct OnboardingView: View {
    let onGetStarted: () -> Void
    let onSkipOrLogin: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0

    private let pages = OnboardingPage.all
    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(AppColors.primary.opacity(colorScheme == .dark ? 0.10 : 0.07))
                .frame(width: 300, height: 300)
                .offset(x: 90, y: -120)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        OnboardingPageView(page: page).tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
                    .padding(24)
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(AppPalette.goldAccent).frame(width: 8, height: 8)
                Text(String(localized: "app_name").uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(AppColors.onBackground)
            }
            Spacer()
            if !isLastPage {
                Button("skip", action: onSkipOrLogin)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.onBackground.opacity(0.7))
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isLastPage {
            VStack(spacing: 12) {
                Button(action: onGetStarted) {
                    HStack(spacing: 8) {
                        Text("get_started").fontWeight(.bold)
                        Circle().fill(AppPalette.goldAccent).frame(width: 6, height: 6)
                    }
                }
                .buttonStyle(OnboardingButtonStyle(filled: true))

                Button("ob_login_cta", action: onSkipOrLogin)
                    .buttonStyle(OnboardingButtonStyle(filled: false))
            }
        } else {
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(pages) { page in
                        Capsule()
                            .fill(page.id == currentPage
                                  ? AppColors.primary
                                  : AppColors.onBackground.opacity(0.2))
                            .frame(width: page.id == currentPage ? 24 : 8, height: 8)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: currentPage)

                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    HStack(spacing: 8) {
                        Text("next").fontWeight(.bold)
                        Image(systemName: "arrow.forward").font(.system(size: 15, weight: .semibold))
                    }
                }
                .buttonStyle(OnboardingButtonStyle(filled: true))
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(page.image)
                    .resizable()
                    .aspectRatio(320 / 280, contentMode: .fit)
                    .frame(width: proxy.size.width * 0.85)
                    .accessibilityHidden(true)
                Spacer().frame(height: 40)
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(AppColors.onBackground)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 16)
                Text(page.description)
                    .appTextStyle(.bodyLarge)
                    .foregroundStyle(AppColors.onBackground.opacity(0.7))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .frame(width: proxy.size.width)
        }
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(filled ? AppColors.onPrimary : AppColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(filled ? AppColors.primary : Color.clear)
            }
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: 16).stroke(AppColors.outline, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview {
    OnboardingView(onGetStarted: {}, onSkipOrLogin: {})
}
