import Foundation

/// An open remote session, as `ConnectionManager` uses it.
public protocol RemoteChannel: AnyObject {
    var events: AsyncStream<RemoteEvent> { get }
    func send(_ key: KeyCode, _ direction: KeyDirection)
    func launch(appLink: String)
    func type(_ text: String) throws
    func close()
}

extension RemoteSession: RemoteChannel {}

/// One pairing attempt, as `ConnectionManager` uses it.
public protocol PairingChannel: AnyObject {
    func start() async throws
    func finish(code: String) async throws
    func cancel()
}

extension PairingSession: PairingChannel {}

/// How `ConnectionManager` reaches the TV; tests swap in a fake.
public protocol TVLinking {
    /// Opens a remote session; returns once the TV has reported its power state.
    func openRemote(host: String) async throws -> RemoteChannel
    func pairing(host: String) -> PairingChannel
    /// Sends Wake-on-LAN for the TV with this MAC address, last seen at `host`.
    func wake(mac: String, host: String) async throws
}

/// The real link: TLS sessions with this device's own client certificate.
public struct LiveLink: TVLinking {
    private let identityStore: IdentityStore
    private let clientName: String

    /// How many times a wake sends the magic packet, and the wait between them: a single UDP packet is easily lost.
    static let wakeRepeats = 3
    static let wakeInterval: TimeInterval = 0.1

    /// - Parameter clientName: how this device is named on the TV while pairing.
    public init(identityStore: IdentityStore, clientName: String) {
        self.identityStore = identityStore
        self.clientName = clientName
    }

    public func openRemote(host: String) async throws -> RemoteChannel {
        try await RemoteSession.open(host: host, identity: try Self.identity(from: identityStore))
    }

    public func pairing(host: String) -> PairingChannel {
        LivePairing(host: host, identityStore: identityStore, clientName: clientName)
    }

    /// Sends the magic packet 3 times, 100 ms apart, each time straight to `host` and then as a broadcast.
    ///
    /// On iPhone, broadcasting needs Apple's multicast entitlement, which a free Apple ID can't get, so the
    /// broadcast usually fails there and that failure is ignored. If every unicast send failed, the last error is
    /// thrown.
    public func wake(mac: String, host: String) async throws {
        try await Self.wake(mac: mac, host: host, port: WakeOnLAN.port, broadcast: true)
    }

    /// `wake(mac:host:)` with the unicast port injectable and the broadcast optional, for tests.
    static func wake(mac: String, host: String, port: UInt16, broadcast: Bool) async throws {
        var unicastError: Error?
        var unicastSent = false
        var broadcastError: Error?
        for round in 0..<wakeRepeats {
            if round > 0 { try? await Task.sleep(for: .seconds(wakeInterval)) }
            do {
                try await WakeOnLAN.send(mac: mac, to: host, port: port)
                unicastSent = true
            } catch {
                unicastError = error
            }
            guard broadcast else { continue }
            do {
                try await WakeOnLAN.send(mac: mac)
            } catch {
                broadcastError = error
            }
        }
        if let broadcastError {
            Log.link.info("Wake-on-LAN broadcast failed (expected on iPhone): \(String(describing: broadcastError), privacy: .public)")
        }
        if let unicastError, !unicastSent {
            Log.link.error("Wake-on-LAN to \(host, privacy: .public) failed: \(String(describing: unicastError), privacy: .public)")
            throw unicastError
        }
        Log.link.info("Wake-on-LAN sent to \(host, privacy: .public)")
    }

    /// This device's identity: the saved one, or on first use a new one (an RSA key and certificate) that is saved.
    /// Logs which, and any failure.
    static func identity(from store: IdentityStore) throws -> ClientIdentity {
        do {
            let result = try store.loadOrCreateReporting()
            switch result.how {
            case .loaded:
                Log.link.debug("Loaded the client identity")
            case .created:
                Log.link.notice("Created and saved a new client identity")
            case .replacedSharedName:
                Log.link.notice("Replaced the client identity named CN=atvremote with one of its own; pair again")
            }
            return result.identity
        } catch {
            Log.link.error("Client identity failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

/// A pairing attempt that loads (or, the first time, creates) this device's identity when it starts, so that
/// work happens off the main thread, then runs a `PairingSession`.
private final class LivePairing: PairingChannel {
    private let host: String
    private let identityStore: IdentityStore
    private let clientName: String

    private let lock = NSLock()
    private var session: PairingSession?
    private var cancelled = false

    init(host: String, identityStore: IdentityStore, clientName: String) {
        self.host = host
        self.identityStore = identityStore
        self.clientName = clientName
    }

    /// - Throws: `.closed` if cancelled first, an `IdentityStore` error, or what `PairingSession.start` throws.
    func start() async throws {
        let session = PairingSession(host: host, identity: try LiveLink.identity(from: identityStore), clientName: clientName)
        let adopted = lock.withLock { () -> Bool in
            guard !cancelled else { return false }
            self.session = session
            return true
        }
        guard adopted else { throw TVLinkError.closed }
        try await session.start()
    }

    /// - Throws: `.closed` before `start`, or what `PairingSession.finish` throws.
    func finish(code: String) async throws {
        guard let session = lock.withLock({ session }) else { throw TVLinkError.closed }
        try await session.finish(code: code)
    }

    func cancel() {
        let session = lock.withLock { () -> PairingSession? in
            cancelled = true
            return self.session
        }
        session?.cancel()
    }
}
