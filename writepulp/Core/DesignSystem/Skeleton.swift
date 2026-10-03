//
//  Skeleton.swift
//  writepulp
//

import SwiftUI

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [.clear, AppColors.skeletonHighlight, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        .offset(x: -width * 0.6 + phase * width * 1.6)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }
}

/// One placeholder shape.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.skeleton)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// Matches PublicationCard: cover, author line, title.
struct PublicationCardSkeleton: View {
    var coverHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBlock(height: coverHeight, cornerRadius: 12)
            SkeletonBlock(width: 70, height: 10)
            SkeletonBlock(height: 14)
            SkeletonBlock(width: 110, height: 10)
        }
    }
}

/// Two-column grid of card placeholders.
struct PublicationGridSkeleton: View {
    var count = 6

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
            ForEach(0..<count, id: \.self) { _ in PublicationCardSkeleton() }
        }
        .padding(16)
        .shimmering()
    }
}

/// Leading circle or square with two text lines.
struct ListRowSkeleton: View {
    var leadingSize: CGFloat = 48
    var isCircle = true

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isCircle {
                    Circle().fill(AppColors.skeleton)
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(AppColors.skeleton)
                }
            }
            .frame(width: leadingSize, height: leadingSize)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 160, height: 13)
                SkeletonBlock(width: 100, height: 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// A column of row placeholders for lists whose first page is loading.
struct ListSkeleton: View {
    var count = 7
    var leadingSize: CGFloat = 48
    var isCircle = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                ListRowSkeleton(leadingSize: leadingSize, isCircle: isCircle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        // Takes only the space it's given (e.g. above the keyboard) and cuts rows off at the bottom;
        // otherwise the overflow is centered and pushes the screen's header up off-screen.
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
        .shimmering()
    }
}
