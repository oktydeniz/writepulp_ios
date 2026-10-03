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
    let service: ReaderService
    var onOpen: (MainRoute) -> Void = { _ in }
    var onSignIn: () -> Void = {}

    var body: some View {
        switch type {
        case .article:
            ArticleReaderView(publicationId: publicationId, service: service, onOpen: onOpen, onSignIn: onSignIn)
        case .magazine:
            MagazineReaderView(publicationId: publicationId, chapterId: chapterId, service: service)
        case .book, .openBook, .script:
            BookReaderView(publicationId: publicationId, chapterId: chapterId, service: service)
        }
    }
}
