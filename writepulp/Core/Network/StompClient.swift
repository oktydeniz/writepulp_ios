//
//  StompClient.swift
//  writepulp
//

import Foundation

/// Minimal STOMP 1.2 client over a plain WebSocket, for the chat topics.
/// Connects on the first subscription, disconnects after the last one ends, and reconnects with
/// backoff in between, subscribing again to everything that's still open.
actor StompClient {
    enum Event {
        case message(Data)
        /// The connection came back after a drop; messages sent meanwhile were missed.
        case reconnected
    }

    private struct Subscription {
        let destination: String
        let continuation: AsyncStream<Event>.Continuation
    }

    private let url: URL
    private let urlSession: URLSession
    private let token: @Sendable () async -> String?

    private var socket: URLSessionWebSocketTask?
    private var isConnected = false
    private var hasConnectedBefore = false
    private var subscriptions: [String: Subscription] = [:]
    private var nextSubscriptionId = 0
    private var reconnectTask: Task<Void, Never>?
    private var failedAttempts = 0

    private static let connectTimeout: Duration = .seconds(10)
    private static let maxBackoffSeconds = 30.0

    init(url: URL, urlSession: URLSession = .shared, token: @escaping @Sendable () async -> String?) {
        self.url = url
        self.urlSession = urlSession
        self.token = token
    }

    /// Frame bodies sent to `destination` until the stream is cancelled.
    func subscribe(_ destination: String) -> AsyncStream<Event> {
        nextSubscriptionId += 1
        let id = "sub-\(nextSubscriptionId)"
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .bufferingNewest(200))
        subscriptions[id] = Subscription(destination: destination, continuation: continuation)
        // The client lives as long as the app, so holding it here creates no lasting cycle.
        continuation.onTermination = { [self] _ in
            Task { await self.unsubscribe(id) }
        }
        if isConnected {
            transmit(Self.frame("SUBSCRIBE", ["id": id, "destination": destination]))
        } else {
            connectIfNeeded()
        }
        return stream
    }

    /// False when not connected; the caller falls back to REST.
    func send(destination: String, body: some Encodable) async -> Bool {
        guard isConnected, let socket,
              let data = try? JSONEncoder().encode(body),
              let json = String(data: data, encoding: .utf8) else { return false }
        let frame = Self.frame(
            "SEND",
            ["destination": destination, "content-type": "application/json", "content-length": String(data.count)],
            body: json
        )
        do {
            try await socket.send(.string(frame))
            return true
        } catch {
            return false
        }
    }

    /// Skips the backoff wait, e.g. when the app returns to the foreground.
    func reconnectIfNeeded() {
        guard !subscriptions.isEmpty, !isConnected else { return }
        reconnectTask?.cancel()
        reconnectTask = nil
        failedAttempts = 0
        connectIfNeeded()
    }

    // MARK: - Connection

    private func connectIfNeeded() {
        guard socket == nil, reconnectTask == nil, !subscriptions.isEmpty else { return }
        let task = urlSession.webSocketTask(with: url)
        socket = task
        task.resume()
        Task { await run(task) }
        Task {
            try? await Task.sleep(for: Self.connectTimeout)
            connectTimedOut(task)
        }
    }

    private func run(_ task: URLSessionWebSocketTask) async {
        guard let token = await token() else {
            connectionLost(task)
            return
        }
        let host = url.host ?? ""
        do {
            try await task.send(.string(Self.frame("CONNECT", [
                "accept-version": "1.2",
                "host": host,
                "heart-beat": "0,0",
                "Authorization": "Bearer \(token)",
            ])))
            while true {
                switch try await task.receive() {
                case .string(let text): handle(text, from: task)
                case .data(let data): handle(String(decoding: data, as: UTF8.self), from: task)
                @unknown default: break
                }
            }
        } catch {
            connectionLost(task)
        }
    }

    private func handle(_ text: String, from task: URLSessionWebSocketTask) {
        guard task === socket else { return }
        // One WebSocket message can carry several frames; bare newlines are heartbeats.
        for raw in text.split(separator: "\u{0}", omittingEmptySubsequences: true) {
            guard let frame = Frame(String(raw)) else { continue }
            switch frame.command {
            case "CONNECTED":
                isConnected = true
                failedAttempts = 0
                for (id, subscription) in subscriptions {
                    transmit(Self.frame("SUBSCRIBE", ["id": id, "destination": subscription.destination]))
                    if hasConnectedBefore { subscription.continuation.yield(.reconnected) }
                }
                hasConnectedBefore = true
            case "MESSAGE":
                guard let id = frame.headers["subscription"] else { continue }
                subscriptions[id]?.continuation.yield(.message(Data(frame.body.utf8)))
            case "ERROR":
                task.cancel(with: .protocolError, reason: nil)
            default:
                break
            }
        }
    }

    private func connectTimedOut(_ task: URLSessionWebSocketTask) {
        // The server drops a CONNECT with a bad token without answering.
        guard task === socket, !isConnected else { return }
        task.cancel(with: .goingAway, reason: nil)
        connectionLost(task)
    }

    private func connectionLost(_ task: URLSessionWebSocketTask) {
        guard task === socket else { return }
        socket = nil
        isConnected = false
        guard !subscriptions.isEmpty else { return }
        let delay = min(Self.maxBackoffSeconds, pow(2, Double(failedAttempts)))
        failedAttempts += 1
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            reconnectTimerFired()
        }
    }

    private func reconnectTimerFired() {
        reconnectTask = nil
        connectIfNeeded()
    }

    private func unsubscribe(_ id: String) {
        guard subscriptions.removeValue(forKey: id) != nil else { return }
        if isConnected { transmit(Self.frame("UNSUBSCRIBE", ["id": id])) }
        if subscriptions.isEmpty { disconnect() }
    }

    private func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        isConnected = false
        hasConnectedBefore = false
        failedAttempts = 0
    }

    private func transmit(_ frame: String) {
        socket?.send(.string(frame)) { _ in }
    }

    // MARK: - Frames

    private static func frame(_ command: String, _ headers: [String: String], body: String = "") -> String {
        var lines = [command]
        for (key, value) in headers { lines.append("\(key):\(value)") }
        return lines.joined(separator: "\n") + "\n\n" + body + "\u{0}"
    }

    private struct Frame {
        let command: String
        let headers: [String: String]
        let body: String

        init?(_ raw: String) {
            let text = raw.replacingOccurrences(of: "\r\n", with: "\n").drop { $0 == "\n" }
            guard !text.isEmpty else { return nil }
            let parts = text.split(separator: "\n\n", maxSplits: 1, omittingEmptySubsequences: false)
            var lines = parts[0].split(separator: "\n").map(String.init)
            guard !lines.isEmpty else { return nil }
            command = lines.removeFirst()
            var headers: [String: String] = [:]
            for line in lines {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<colon])
                // The first occurrence of a repeated header wins.
                if headers[key] == nil { headers[key] = String(line[line.index(after: colon)...]) }
            }
            self.headers = headers
            body = parts.count > 1 ? String(parts[1]) : ""
        }
    }
}
