import Foundation

/// Looks for TVs for as long as the calling task runs, without giving up, as the setup screen uses it.
///
/// A single discovery can come up empty for good: its browse or its address lookups may fail while iOS still
/// waits for the user to allow local network access, and it gives up on a TV after a few lookups. So while the
/// TVs found so far are none, the finder is stopped and replaced by a fresh one every `restartInterval` seconds.
/// Once a TV is found the finder keeps running and its list stays live; should the list empty again, the restarts
/// resume.
@MainActor
public enum TVSearch {
    /// Runs until the calling task is cancelled, then stops the finder and returns.
    /// - Parameters:
    ///   - makeFinder: makes a fresh, not yet started finder.
    ///   - onDenied: becomes each finder's `onPolicyDenied`, so it may be called on any queue.
    ///   - onResults: every list of TVs found, starting over with each fresh finder.
    public static func run(
        restartInterval: TimeInterval = 5,
        makeFinder: () -> TVFinding,
        onDenied: @escaping () -> Void,
        onResults: @escaping ([DiscoveredTV]) -> Void
    ) async {
        while !Task.isCancelled {
            let finder = makeFinder()
            finder.onPolicyDenied = onDenied
            let latest = LatestList()
            // Stopping the finder ends its results, which ends the loop below.
            let watchdog = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(restartInterval))
                    if !Task.isCancelled, latest.tvs.isEmpty {
                        finder.stop()
                        return
                    }
                }
            }
            finder.start()
            for await list in finder.results {
                latest.tvs = list
                onResults(list)
            }
            watchdog.cancel()
            finder.stop()
        }
    }
}

/// The last list a finder reported.
@MainActor
private final class LatestList {
    var tvs: [DiscoveredTV] = []
}
