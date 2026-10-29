import Foundation
import TVRemoteKit

/// A stand-in for the TV, used with the `-demo` launch argument: always connected, TV on, volume 12/100.
/// Lets the UI be shown and screenshotted without a TV on the network.
struct DemoLink: TVLinking {
    func openRemote(host: String) async throws -> RemoteChannel {
        DemoChannel()
    }

    func pairing(host: String) -> PairingChannel {
        DemoPairing()
    }

    func wake(mac: String, host: String) async throws {}
}

/// The TV that `-demo` pretends to have paired.
struct DemoStore: PairedTVStore {
    func load() -> PairedTV? {
        PairedTV(host: "192.168.8.16", name: "Living room TV", mac: "44:0f:b4:88:a4:9b")
    }

    func save(_ tv: PairedTV?) {}
}

private final class DemoChannel: RemoteChannel {
    let events: AsyncStream<RemoteEvent>

    init() {
        events = AsyncStream { continuation in
            continuation.yield(.ready(isOn: true))
            continuation.yield(.volume(level: 12, max: 100, muted: false))
        }
    }

    func send(_ key: KeyCode, _ direction: KeyDirection) {}
    func launch(appLink: String) {}
    func type(_ text: String) throws {}
    func close() {}
}

private final class DemoPairing: PairingChannel {
    func start() async throws {}
    func finish(code: String) async throws {}
    func cancel() {}
}
