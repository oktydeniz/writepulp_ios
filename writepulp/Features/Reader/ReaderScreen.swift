//
//  ReaderScreen.swift
//  writepulp
//

import SwiftUI

/// Picks the reader for a publication type. Scripts use the chapter reader.
@MainActor
struct ReaderScreen: View {
    let publicationId: String
    let type: PublicationType
    let chapterId: String?
    /// The owner or a co-worker reading their own work: no coin session, progress or view counts.
    var asEditor = false
    let service: ReaderService
    var onOpen: (MainRoute) -> Void = { _ in }
    var onSignIn: () -> Void = {}

    var body: some View {
        switch type {
        case .article:
            ArticleReaderView(publicationId: publicationId, asEditor: asEditor, service: service, onOpen: onOpen, onSignIn: onSignIn)
        case .magazine:
            MagazineReaderView(publicationId: publicationId, chapterId: chapterId, asEditor: asEditor, service: service)
        case .book, .openBook, .script:
            BookReaderView(publicationId: publicationId, chapterId: chapterId, asEditor: asEditor, service: service)
        }
    }
}
