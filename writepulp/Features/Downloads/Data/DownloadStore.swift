//
//  DownloadStore.swift
//  writepulp
//

import CryptoKit
import Foundation

/// On-disk storage of downloads. Layout per publication:
/// `<id>/manifest.json`, `<id>/bodies/<sectionId>.json`, `<id>/media/<file>`, `<id>/progress.json`.
/// New copies are built in a draft folder and swapped in only when complete.
actor DownloadStore {
    nonisolated let rootURL: URL
    private let fileManager = FileManager.default
    private var manifests: [String: DownloadedPublication]?

    init(rootURL: URL? = nil) {
        let base = rootURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        self.rootURL = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Re-downloadable content: keep it out of iCloud backups.
        var url = base
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Reading

    func all() -> [DownloadedPublication] {
        Array(loadManifests().values)
    }

    func publication(_ id: String) -> DownloadedPublication? {
        loadManifests()[id]
    }

    func body(publicationId: String, sectionId: String) -> String? {
        let url = Self.bodyURL(in: directory(publicationId), sectionId: sectionId)
        return (try? Data(contentsOf: url)).flatMap { String(data: $0, encoding: .utf8) }
    }

    nonisolated func mediaURL(publicationId: String, file: String) -> URL {
        rootURL.appendingPathComponent(publicationId).appendingPathComponent("media").appendingPathComponent(file)
    }

    // MARK: - Progress

    func progress(publicationId: String) -> [String: LocalProgress] {
        let url = directory(publicationId).appendingPathComponent("progress.json")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: LocalProgress].self, from: data)) ?? [:]
    }

    /// Keeps the highest percent; the read time always moves forward.
    func recordProgress(publicationId: String, sectionId: String, percent: Double) {
        guard loadManifests()[publicationId] != nil else { return }
        var all = progress(publicationId: publicationId)
        all[sectionId] = LocalProgress(percent: max(all[sectionId]?.percent ?? 0, percent), readAt: Date())
        let url = directory(publicationId).appendingPathComponent("progress.json")
        try? JSONEncoder().encode(all).write(to: url, options: .atomic)
    }

    // MARK: - Writing

    func makeDraft(publicationId: String) throws -> DownloadDraft {
        let draftURL = rootURL.appendingPathComponent(".draft-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: draftURL.appendingPathComponent("bodies"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: draftURL.appendingPathComponent("media"), withIntermediateDirectories: true)
        let existing = directory(publicationId)
        return DownloadDraft(
            directory: draftURL,
            previousMedia: fileManager.fileExists(atPath: existing.path) ? existing.appendingPathComponent("media") : nil
        )
    }

    /// Replaces the current copy (if any) with the draft, keeping the local reading progress.
    func commit(_ draft: DownloadDraft, manifest: DownloadedPublication) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: draft.directory.appendingPathComponent("manifest.json"), options: .atomic)

        let target = directory(manifest.id)
        if fileManager.fileExists(atPath: target.path) {
            let progress = target.appendingPathComponent("progress.json")
            if fileManager.fileExists(atPath: progress.path) {
                try? fileManager.copyItem(at: progress, to: draft.directory.appendingPathComponent("progress.json"))
            }
            _ = try fileManager.replaceItemAt(target, withItemAt: draft.directory)
        } else {
            try fileManager.moveItem(at: draft.directory, to: target)
        }
        manifests?[manifest.id] = manifest
    }

    func discard(_ draft: DownloadDraft) {
        try? fileManager.removeItem(at: draft.directory)
    }

    func delete(_ id: String) {
        try? fileManager.removeItem(at: directory(id))
        manifests?[id] = nil
    }

    // MARK: - Private

    private func directory(_ id: String) -> URL {
        rootURL.appendingPathComponent(id, isDirectory: true)
    }

    private func loadManifests() -> [String: DownloadedPublication] {
        if let manifests { return manifests }
        var loaded: [String: DownloadedPublication] = [:]
        let entries = (try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
        for entry in entries {
            // Leftover drafts of an interrupted download.
            if entry.lastPathComponent.hasPrefix(".draft-") {
                try? fileManager.removeItem(at: entry)
                continue
            }
            let url = entry.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(DownloadedPublication.self, from: data) else { continue }
            loaded[manifest.id] = manifest
        }
        manifests = loaded
        return loaded
    }

    fileprivate static func bodyURL(in directory: URL, sectionId: String) -> URL {
        directory.appendingPathComponent("bodies").appendingPathComponent("\(sectionId).json")
    }
}

/// A copy being built. File writes happen off the store's actor; only commit/discard go through it.
struct DownloadDraft: Sendable {
    let directory: URL
    /// Media of the copy being replaced, reused instead of downloading the same file again.
    let previousMedia: URL?

    func writeBody(_ body: String, sectionId: String) throws {
        try Data(body.utf8).write(to: DownloadStore.bodyURL(in: directory, sectionId: sectionId))
    }

    /// Saved file name for a remote path, or nil when it isn't present yet.
    func existingMedia(for remotePath: String) -> String? {
        let name = Self.fileName(for: remotePath)
        let target = mediaURL(name)
        if FileManager.default.fileExists(atPath: target.path) { return name }
        if let previous = previousMedia?.appendingPathComponent(name),
           (try? FileManager.default.copyItem(at: previous, to: target)) != nil {
            return name
        }
        return nil
    }

    func storeMedia(at temporaryURL: URL, for remotePath: String) throws -> String {
        let name = Self.fileName(for: remotePath)
        let target = mediaURL(name)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: temporaryURL, to: target)
        return name
    }

    private func mediaURL(_ name: String) -> URL {
        directory.appendingPathComponent("media").appendingPathComponent(name)
    }

    static func fileName(for remotePath: String) -> String {
        let hash = SHA256.hash(data: Data(remotePath.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = remotePath.split(separator: "?").first.map(String.init) ?? remotePath
        let ext = (path as NSString).pathExtension.lowercased()
        return "\(hash).\(ext.isEmpty || ext.count > 5 ? "img" : ext)"
    }
}
