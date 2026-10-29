import Foundation
import TVRemoteKit

/// Launch arguments that stand in for a TV, so the screens can be shown and screenshotted without one.
enum DemoMode {
    /// `-demo`: a TV is paired and always connected.
    case connected
    /// `-demoSetup`: no TV is paired and the TV list holds one TV.
    case setup
    /// `-demoPairing`: pairing has started and the code is on the (pretend) TV. The code is 123456.
    case pairing
    /// `-demoWrongCode`: like `-demoPairing`, after a wrong code.
    case wrongCode

    /// The mode the app was launched in, if any.
    static let current: DemoMode? = {
        let arguments = CommandLine.arguments
        if arguments.contains("-demoWrongCode") { return .wrongCode }
        if arguments.contains("-demoPairing") { return .pairing }
        if arguments.contains("-demoSetup") { return .setup }
        if arguments.contains("-demo") { return .connected }
        return nil
    }()

    /// The one TV the demo knows about.
    static let tv = DiscoveredTV(id: "demo", name: "Smart TV Pro", host: "192.168.8.16")

    var store: PairedTVStore {
        self == .connected ? DemoStore() : DemoEmptyStore()
    }

    /// The TV the setup screen starts out pairing with.
    var pairingTarget: DiscoveredTV? {
        self == .pairing || self == .wrongCode ? Self.tv : nil
    }

    /// Brings the connection to where the mode starts.
    @MainActor
    func prepare(_ connection: ConnectionManager) async {
        guard let target = pairingTarget else { return }
        await connection.startPairing(host: target.host, name: target.name)
        if self == .wrongCode {
            await connection.submitCode("000000")
        }
    }
}

/// A stand-in for the TV: always connected, TV on, volume 12/100. Pairing succeeds with the code 123456.
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

/// No TV paired, and none ever saved.
struct DemoEmptyStore: PairedTVStore {
    func load() -> PairedTV? { nil }
    func save(_ tv: PairedTV?) {}
}

/// Finds the demo TV, and keeps "looking" until stopped.
final class DemoFinder: TVFinding {
    let results: AsyncStream<[DiscoveredTV]>
    var onPolicyDenied: (() -> Void)?
    private let continuation: AsyncStream<[DiscoveredTV]>.Continuation

    init() {
        (results, continuation) = AsyncStream.makeStream(of: [DiscoveredTV].self)
    }

    func start() {
        continuation.yield([DemoMode.tv])
    }

    func stop() {
        continuation.finish()
    }
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

    func finish(code: String) async throws {
        guard code == "123456" else { throw TVLinkError.badCode }
    }

    func cancel() {}
}
