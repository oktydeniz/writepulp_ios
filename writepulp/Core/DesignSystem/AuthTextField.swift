//
//  AuthTextField.swift
//  writepulp
//

import SwiftUI

/// Labeled, rounded input used across the auth screens.
/// Focus is owned by the screen (`focus` + `field`), so "Next" can move to the following field
/// and a tap on the background can dismiss the keyboard.
struct AuthTextField<Field: Hashable>: View {
    let label: LocalizedStringKey
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<Field?>.Binding
    let field: Field
    var systemImage: String?
    var isSecure = false
    var isError = false
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    private var isFocused: Bool { focus.wrappedValue == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)

            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(isFocused ? AppColors.primary : AppPalette.appLightGray)
                        .frame(width: 22)
                }
                input
                    .focused(focus, equals: field)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .foregroundStyle(AppColors.onSurface)
                if isSecure {
                    Button {
                        isRevealed.toggle()
                        // Swapping SecureField/TextField drops focus; keep the keyboard up.
                        DispatchQueue.main.async { focus.wrappedValue = field }
                    } label: {
                        Image(systemName: isRevealed ? "eye" : "eye.slash")
                            .foregroundStyle(isFocused ? AppColors.primary : AppPalette.appLightGray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: isFocused || isError ? 2 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field }
        }
    }

    private var borderColor: Color {
        if isError { return AppColors.error }
        return isFocused ? AppColors.primary : AppColors.outline
    }

    @ViewBuilder
    private var input: some View {
        let prompt = Text(placeholder).foregroundStyle(AppPalette.appLightGray)
        if isSecure && !isRevealed {
            SecureField("", text: $text, prompt: prompt)
        } else {
            TextField("", text: $text, prompt: prompt)
        }
    }
}

extension View {
    /// Taps on empty space (not on fields or buttons) clear the focus, closing the keyboard.
    func dismissesKeyboardOnTap<Field: Hashable>(_ focus: FocusState<Field?>.Binding) -> some View {
        contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = nil }
    }
}
