//
//  Buttons.swift
//  writepulp
//

import SwiftUI

/// Full-width filled button (56pt, 16 radius) used for the main action of a screen.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                AppPalette.primaryColor.opacity(isEnabled ? 1 : 0.5),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: AppPalette.primaryColor.opacity(isEnabled ? 0.3 : 0), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }
}

/// Plain text button in the on-surface color, like the auth screens' secondary links.
struct TextLinkButton: View {
    let title: LocalizedStringKey
    var color: Color = AppColors.onSurface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Checkbox with a trailing title, for toggles like "Remember me".
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(configuration.isOn ? AppColors.secondaryContainer : AppPalette.appLightGray)
                configuration.label
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.onSurface)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var writePulpCheckbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
