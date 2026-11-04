//
//  CreateTranslationSheet.swift
//  writepulp
//

import SwiftUI

/// Starts another language's edition: a draft holding a copy of the original's text.
struct CreateTranslationSheet: View {
    /// Languages the work already exists in.
    let excludedLanguages: [String]
    /// true once the translation exists and the sheet can close.
    let onCreate: (_ title: String, _ language: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var language = ""
    @State private var isSaving = false

    private var languages: [String] {
        ContentLanguage.codes.filter { !excludedLanguages.contains($0) }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if languages.isEmpty {
                    Text("editor_translation_no_languages")
                } else {
                    Section {
                        TextField("editor_translation_title", text: $title)
                        Picker("editor_work_language", selection: $language) {
                            ForEach(languages, id: \.self) { code in
                                Text(ContentLanguage.displayName(for: code)).tag(code)
                            }
                        }
                    } footer: {
                        Text("editor_translation_note")
                    }
                }
            }
            .navigationTitle("editor_create_translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("editor_create") {
                            Task {
                                isSaving = true
                                let created = await onCreate(trimmedTitle, language)
                                isSaving = false
                                if created { dismiss() }
                            }
                        }
                        .disabled(trimmedTitle.isEmpty || language.isEmpty)
                    }
                }
            }
            .onAppear { if language.isEmpty { language = languages.first ?? "" } }
        }
        .presentationDetents([.medium])
    }
}
