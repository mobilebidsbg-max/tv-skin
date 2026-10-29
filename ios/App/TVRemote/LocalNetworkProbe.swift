import Foundation
import TVRemoteKit

/// Checks whether iOS lets the app use the local network, by browsing for TVs for a moment. Setup finds this out
/// by itself; the probe covers the other case, an app that already has a paired TV.
@MainActor
final class LocalNetworkProbe {
    /// How long a probe browses at most.
    private static let duration: Duration = .seconds(3)

    private var task: Task<Void, Never>?
    private var discovery: TVDiscovery?

    /// Browses until a TV turns up (so access is clearly allowed) or the time is up, and calls `onDenied` if iOS
    /// reports the local network blocked. Replaces a probe that is still running.
    func run(onDenied: @escaping @MainActor () -> Void) {
        stop()
        let discovery = TVDiscovery()
        discovery.onPolicyDenied = { Task { @MainActor in onDenied() } }
        self.discovery = discovery
        discovery.start()
        task = Task {
            await Self.waitForATV(on: discovery)
            discovery.stop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        discovery?.stop()
        discovery = nil
    }

    private static func waitForATV(on discovery: TVDiscovery) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await list in discovery.results where !list.isEmpty { return }
            }
            group.addTask { try? await Task.sleep(for: duration) }
            await group.next()
            group.cancelAll()
        }
    }
}
