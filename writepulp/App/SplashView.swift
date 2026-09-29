//
//  SplashView.swift
//  writepulp

import SwiftUI

struct SplashView: View {
    static let logoSize: CGFloat = 120

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            Image("WritePulpLogo")
                .resizable()
                .scaledToFit()
                .frame(width: Self.logoSize, height: Self.logoSize)
                .accessibilityHidden(true)
        }
        .task {
         try? await Task.sleep(for: .milliseconds(800))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
