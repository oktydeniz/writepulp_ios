//
//  ModerationService.swift
//  writepulp
//

import Foundation
import Observation
import SwiftUI

/// Reports, blocks and the Community Guidelines. Also remembers, for this device and account,
/// what the user reported or blocked, so screens can hide it right away instead of waiting
/// for a reload (the server filters blocked users on its side too).
@MainActor
@Observable
final class ModerationService {
    private(set) var blockedUserIds: Set<String> = []
    private(set) var reportedKeys: Set<String> = []

    private let api: APIClient
    private let session: SessionStore
    private let defaults: UserDefaults
    @ObservationIgnored private var loadedForUserId: String?

    nonisolated init(api: APIClient, session: SessionStore, defaults: UserDefaults = .standard) {
        self.api = api
        self.session = session
        self.defaults = defaults
    }

    var currentUserId: String? { session.userId }

    func isHidden(_ target: ReportTarget) -> Bool { reportedKeys.contains(target.key) }

    func isBlocked(userId: String) -> Bool { blockedUserIds.contains(userId) }

    /// Hidden for this viewer: reported by them, or written by someone blocked either way.
    func isHidden(_ target: ReportTarget, authorId: String?) -> Bool {
        isHidden(target) || authorId.map(isBlocked(userId:)) == true
    }

    // MARK: - Session

    /// Loads the block list and local report history for the signed-in account; clears them on sign-out.
    func refresh() async {
        guard session.isLoggedIn, let userId = session.userId else {
            blockedUserIds = []
            reportedKeys = []
            loadedForUserId = nil
            return
        }
        if loadedForUserId != userId {
            reportedKeys = Set(defaults.stringArray(forKey: reportedStorageKey(userId)) ?? [])
            loadedForUserId = userId
        }
        if let page = try? await api.send(ModerationAPI.blockedUsers(page: 0)) {
            blockedUserIds = Set(page.content.map(\.user.uuid))
        }
    }

    // MARK: - Reports

    func report(_ target: ReportTarget, reason: ReportReason, note: String) async throws {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await api.send(ModerationAPI.report(CreateReportRequest(
                targetType: target.type,
                targetId: target.id,
                reason: reason,
                note: trimmed.isEmpty ? nil : trimmed
            )))
        } catch let error as APIError where error.businessCode == Self.alreadyReportedCode {
            // Reported before: still hide it here.
        }
        reportedKeys.insert(target.key)
        if let userId = session.userId {
            defaults.set(Array(reportedKeys), forKey: reportedStorageKey(userId))
        }
    }

    // MARK: - Blocks

    func block(userId: String) async throws {
        _ = try await api.send(ModerationAPI.block(userId: userId))
        blockedUserIds.insert(userId)
    }

    func unblock(userId: String) async throws {
        _ = try await api.send(ModerationAPI.unblock(userId: userId))
        blockedUserIds.remove(userId)
    }

    func blockedUsers(page: Int) async throws -> Page<BlockedUser> {
        try await api.send(ModerationAPI.blockedUsers(page: page, size: 20))
    }

    // MARK: - Community Guidelines

    func termsStatus() async throws -> TermsStatus {
        try await api.send(ModerationAPI.termsStatus())
    }

    func acceptTerms(version: String) async throws {
        _ = try await api.send(ModerationAPI.acceptTerms(version: version))
    }

    /// Backend ALREADY_EXISTS, sent when this user already has an open report on the target.
    private static let alreadyReportedCode = 409

    private func reportedStorageKey(_ userId: String) -> String { "moderation.reported.\(userId)" }
}

extension EnvironmentValues {
    /// nil in previews and for screens shown outside the signed-in shell.
    @Entry var moderation: ModerationService?
}
