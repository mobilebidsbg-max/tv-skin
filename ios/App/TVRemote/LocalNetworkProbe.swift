import Foundation
import TVRemoteKit

/// Browses for TVs for a moment each time the app becomes active. It finds out whether iOS lets the app use the
/// local network (setup finds this out by itself; the probe covers an app that already has a paired TV), and it
/// passes the TVs it finds on, so the app notices when the paired TV has moved to another address.
@MainActor
final class LocalNetworkProbe {
    /// How long a probe browses at most.
    private static let duration: Duration = .seconds(10)

    private var task: Task<Void, Never>?
    private var discovery: TVDiscovery?

    /// Browses until a TV named `name` turns up (any TV when `name` is nil) or the time is up. Every list of TVs
    /// found goes to `onFound`; `onDenied` runs if iOS reports the local network blocked. Replaces a probe that is
    /// still running.
    func run(
        lookingFor name: String?,
        onFound: @escaping @MainActor ([DiscoveredTV]) -> Void,
        onDenied: @escaping @MainActor () -> Void
    ) {
        stop()
        let discovery = TVDiscovery()
        discovery.onPolicyDenied = { Task { @MainActor in onDenied() } }
        self.discovery = discovery
        discovery.start()
        task = Task {
            await Self.browse(discovery, until: { list in
                name.map { name in list.contains { $0.name == name } } ?? !list.isEmpty
            }, onFound: onFound)
            discovery.stop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        discovery?.stop()
        discovery = nil
    }

    private static func browse(
        _ discovery: TVDiscovery,
        until done: @escaping @Sendable ([DiscoveredTV]) -> Bool,
        onFound: @escaping @MainActor ([DiscoveredTV]) -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await list in discovery.results {
                    await onFound(list)
                    if done(list) { return }
                }
            }
            group.addTask { try? await Task.sleep(for: duration) }
            await group.next()
            group.cancelAll()
        }
    }
}
