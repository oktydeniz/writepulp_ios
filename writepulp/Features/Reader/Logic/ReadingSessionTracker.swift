//
//  ReadingSessionTracker.swift
//  writepulp
//

import Foundation

/// Reading session for coins: started per publication/section, pinged every 30s while the
/// reader is on screen, stopped when it goes away. The server enforces the daily cap; `dailyTotal`
/// only stops the pings once it's reached.
@MainActor
final class ReadingSessionTracker {
    private static let interval: Duration = .seconds(30)
    private static let dailyMaxCoins = 60

    private let service: ReaderService
    private var loop: Task<Void, Never>?
    private var sessionId: String?
    private var activeKey: String?
    /// The last requested session, so it can resume after the app comes back to the foreground.
    private var requested: (publicationId: String, sectionId: String)?
    private var isPaused = false

    init(service: ReaderService) {
        self.service = service
    }

    func update(publicationId: String, sectionId: String, enabled: Bool) {
        guard enabled, service.isSignedIn else {
            requested = nil
            stop()
            return
        }
        requested = (publicationId, sectionId)
        guard !isPaused else { return }
        let key = "\(publicationId):\(sectionId)"
        if key == activeKey, loop != nil { return }
        stop()
        activeKey = key
        loop = Task { [weak self] in
            await self?.run(publicationId: publicationId, sectionId: sectionId)
        }
    }

    func pause() {
        isPaused = true
        stop()
    }

    func resume() {
        isPaused = false
        if let requested {
            update(publicationId: requested.publicationId, sectionId: requested.sectionId, enabled: true)
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        activeKey = nil
        if let sessionId {
            self.sessionId = nil
            let service = service
            Task { await service.stopSession(sessionId: sessionId) }
        }
    }

    private func run(publicationId: String, sectionId: String) async {
        guard let session = try? await service.startSession(publicationId: publicationId, sectionId: sectionId) else { return }
        // Left the chapter while the session was being created.
        if Task.isCancelled {
            await service.stopSession(sessionId: session.sessionId)
            return
        }
        sessionId = session.sessionId
        var anchor = Date()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.interval)
            if Task.isCancelled { return }
            let elapsed = Int(Date().timeIntervalSince(anchor))
            let response = try? await service.heartbeat(sessionId: session.sessionId, sectionId: sectionId, elapsedSeconds: elapsed)
            anchor = Date()
            if let total = response?.dailyTotal, total >= Self.dailyMaxCoins { return }
        }
    }
}

/// Progress is sent at most every 3.5s and only after moving at least 2%.
struct ProgressThrottle {
    private var lastSent = Date.distantPast
    private var lastValue: Double = 0

    mutating func reset(to value: Double?) {
        lastSent = .distantPast
        lastValue = value ?? 0
    }

    mutating func shouldSend(_ percent: Double, now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(lastSent) >= 3.5, abs(percent - lastValue) >= 2 else { return false }
        lastSent = now
        lastValue = percent
        return true
    }
}
