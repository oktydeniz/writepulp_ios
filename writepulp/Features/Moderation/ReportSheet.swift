//
//  ReportSheet.swift
//  writepulp
//

import SwiftUI

/// Pick a reason, optionally explain, send. After sending, the content is hidden for this user.
struct ReportSheet: View {
    let target: ReportTarget
    let onReported: () -> Void

    @Environment(\.moderation) private var moderation
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var isDone = false

    var body: some View {
        NavigationStack {
            Group {
                if isDone {
                    confirmation
                } else {
                    form
                }
            }
            .navigationTitle(Text("report_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDone ? "close" : "cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var form: some View {
        Form {
            Section {
                ForEach(ReportReason.allCases) { option in
                    Button {
                        reason = option
                    } label: {
                        HStack {
                            Text(option.title).foregroundStyle(AppColors.onSurface)
                            Spacer()
                            if reason == option {
                                Image(systemName: "checkmark").foregroundStyle(AppColors.primary)
                            }
                        }
                    }
                }
            } header: {
                Text("report_reason_header")
            } footer: {
                Text("report_footer")
            }

            Section("report_note_header") {
                TextField("report_note_placeholder", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(AppColors.error)
                }
            }

            Section {
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending { ProgressView() } else { Text("report_submit").bold() }
                        Spacer()
                    }
                }
                .disabled(reason == nil || isSending)
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primary)
            Text("report_thanks_title")
                .font(.system(size: 20, weight: .bold))
            Text("report_thanks_body")
                .font(.system(size: 15))
                .foregroundStyle(AppColors.onSurface.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() async {
        guard let reason, let moderation else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await moderation.report(target, reason: reason, note: note)
            onReported()
            withAnimation { isDone = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension View {
    /// Presents the report sheet while [target] is set.
    func reportSheet(_ target: Binding<ReportTarget?>, onReported: @escaping (ReportTarget) -> Void = { _ in }) -> some View {
        sheet(item: target) { item in
            ReportSheet(target: item) { onReported(item) }
        }
    }
}
