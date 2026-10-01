//
//  ImageViewer.swift
//  writepulp
//

import SwiftUI

/// Full-screen image; tap or swipe down to close.
struct ImageViewer: View {
    let imagePath: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: AppEnvironment.imageURL(imagePath)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("close"))
            .padding()
        }
        .onTapGesture { dismiss() }
        .gesture(DragGesture().onEnded { if $0.translation.height > 80 { dismiss() } })
    }
}
