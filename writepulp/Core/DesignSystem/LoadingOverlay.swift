//
//  LoadingOverlay.swift
//  writepulp
//

import SwiftUI

/// Dims the screen and blocks touches while a request is running.
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppColors.primary)
                        .padding(28)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading))
    }
}
