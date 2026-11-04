//
//  EditorRoute.swift
//  writepulp
//

import SwiftUI

/// Every screen of the writing flow. The app shell only knows `MainRoute.editor(_:)`;
/// what each case shows lives here, so editor changes stay inside this folder.
enum EditorRoute: Hashable {
    /// The writer's works.
    case dashboard
    case createWork(type: PublicationType)
    /// Chapters and settings of one work.
    case work(id: String)
    /// Members of one work; the owner invites and manages them here.
    case team(workId: String)
    /// Title, cover, categories and the other details of one work.
    case workSettings(workId: String)
    /// nil section: a new one.
    case section(workId: String, sectionId: String?)
}

/// What the editor screens can ask of the app shell's navigation.
struct EditorNavigator {
    let open: (EditorRoute) -> Void
    let replaceTop: (EditorRoute) -> Void
    let pop: () -> Void
    /// The public page of a work, for team members who can't manage it.
    let openPublication: (String) -> Void
    /// For readers, who have to become authors in Settings first.
    let openSettings: () -> Void
}

@MainActor
struct EditorDestination: View {
    let route: EditorRoute
    let service: EditorService
    let navigator: EditorNavigator

    var body: some View {
        switch route {
        case .dashboard:
            WriterDashboardView(service: service, navigator: navigator)
        case .createWork(let type):
            CreateWorkView(type: type, service: service) { id in
                navigator.replaceTop(.work(id: id))
            }
        case .work(let id):
            WorkManagerView(workId: id, service: service, navigator: navigator)
        case .team(let workId):
            WorkTeamView(workId: workId, service: service)
        case .workSettings(let workId):
            WorkSettingsView(workId: workId, service: service, onSaved: navigator.pop)
        case .section(let workId, let sectionId):
            SectionComposerView(workId: workId, sectionId: sectionId, service: service, onClose: navigator.pop)
        }
    }
}
