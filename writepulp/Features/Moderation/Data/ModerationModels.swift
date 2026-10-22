//
//  ModerationModels.swift
//  writepulp
//

import Foundation

/// What a report points at; raw values match the backend.
enum ReportTargetType: String, Encodable {
    case publication = "PUBLICATION"
    case section = "SECTION"
    case publicationReview = "PUBLICATION_REVIEW"
    case sectionReview = "SECTION_REVIEW"
    case group = "GROUP"
    case groupMessage = "GROUP_MESSAGE"
    case user = "USER"
}

enum ReportReason: String, Encodable, CaseIterable, Identifiable {
    case spam = "SPAM"
    case harassment = "HARASSMENT"
    case hateSpeech = "HATE_SPEECH"
    case sexualContent = "SEXUAL_CONTENT"
    case violence = "VIOLENCE"
    case selfHarm = "SELF_HARM"
    case childSafety = "CHILD_SAFETY"
    case copyright = "COPYRIGHT"
    case impersonation = "IMPERSONATION"
    case other = "OTHER"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .spam: "report_reason_spam"
        case .harassment: "report_reason_harassment"
        case .hateSpeech: "report_reason_hate_speech"
        case .sexualContent: "report_reason_sexual_content"
        case .violence: "report_reason_violence"
        case .selfHarm: "report_reason_self_harm"
        case .childSafety: "report_reason_child_safety"
        case .copyright: "report_reason_copyright"
        case .impersonation: "report_reason_impersonation"
        case .other: "report_reason_other"
        }
    }
}

/// Something the user can report from a menu; drives the report sheet.
struct ReportTarget: Identifiable, Hashable {
    let type: ReportTargetType
    let id: String

    var key: String { "\(type.rawValue):\(id)" }
}

struct CreateReportRequest: Encodable {
    let targetType: ReportTargetType
    let targetId: String
    let reason: ReportReason
    let note: String?
}

struct BlockedUser: Decodable, Identifiable {
    struct User: Decodable {
        let uuid: String
        let fullName: String
        let handle: String
        let avatarImg: String?
    }

    let user: User
    let blockedAt: String

    var id: String { user.uuid }
}

struct TermsStatus: Decodable {
    let currentVersion: String
    let acceptedVersion: String?
    let requiresAcceptance: Bool
}

struct AcceptTermsRequest: Encodable {
    let version: String
}
