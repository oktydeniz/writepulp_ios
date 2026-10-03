//
//  NetworkMonitor.swift
//  writepulp
//

import Network
import Observation

/// Live connectivity state. Starts optimistic until the first path update arrives.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    /// Cellular or personal hotspot.
    private(set) var isExpensive = false
    /// False until the first real path update.
    private(set) var isResolved = false

    /// Online over Wi-Fi or wired: fine for large background transfers.
    var isOnUnmeteredNetwork: Bool { isResolved && isOnline && !isExpensive }

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.isExpensive = path.isExpensive || path.isConstrained
                self?.isResolved = true
            }
        }
        monitor.start(queue: DispatchQueue(label: "writepulp.network-monitor", qos: .utility))
    }

    /// Waits briefly for the first path update, e.g. when launched in the background.
    @MainActor
    func waitUntilResolved(timeout: Duration = .seconds(3)) async {
        let deadline = ContinuousClock.now + timeout
        while !isResolved, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    deinit {
        monitor.cancel()
    }
}
