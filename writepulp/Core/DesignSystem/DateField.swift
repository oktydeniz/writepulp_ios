//
//  DateField.swift
//  writepulp
//

import SwiftUI

/// Field styled like AuthTextField that picks a date in a sheet; empty until the user picks one.
struct DateField: View {
    let label: LocalizedStringKey
    @Binding var date: Date?
    var range: ClosedRange<Date>
    /// Where the wheel starts when nothing is picked yet.
    var initialDate: Date
    var isError = false

    @State private var isPicking = false
    @State private var draft = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.onSurface)

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                draft = date ?? initialDate
                isPicking = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppPalette.appLightGray)
                        .frame(width: 22)
                    Text(date.map { $0.formatted(date: .numeric, time: .omitted) } ?? placeholder)
                        .foregroundStyle(date == nil ? AppPalette.appLightGray : AppColors.onSurface)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isError ? AppColors.error : AppColors.outline, lineWidth: isError ? 2 : 1)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPicking) {
            VStack(spacing: 16) {
                DatePicker("", selection: $draft, in: range, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                PrimaryButton(title: "ok") {
                    date = draft
                    isPicking = false
                }
            }
            .padding(24)
            .presentationDetents([.height(340)])
        }
    }

    private var placeholder: String {
        "\(String(localized: "dd")) / \(String(localized: "mm")) / \(String(localized: "yyyy"))"
    }
}
