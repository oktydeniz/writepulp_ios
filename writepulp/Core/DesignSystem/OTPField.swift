//
//  OTPField.swift
//  writepulp
//

import SwiftUI

/// Six code boxes backed by one hidden field, so paste and SMS/email code autofill work.
struct OTPField: View {
    @Binding var code: String
    var length = FormValidator.otpLength
    var isError = false

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.02)
                .onChange(of: code) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(length))
                    if digits != newValue { code = digits }
                }

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    box(at: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
        .onAppear { isFocused = true }
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let isCurrent = isFocused && index == min(characters.count, length - 1)
        let borderColor: Color = isError ? AppColors.error : (isCurrent ? AppColors.primary : AppColors.outline)
        return Text(index < characters.count ? String(characters[index]) : "")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AppColors.onSurface)
            .frame(width: 48, height: 56)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
            }
    }
}
