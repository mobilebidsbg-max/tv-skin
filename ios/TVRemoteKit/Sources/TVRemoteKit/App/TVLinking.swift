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

    /// - Parameter clientName: how this device is named on the TV while pairing (the app passes the device name).
    public init(identityStore: IdentityStore, clientName: String) {
        self.identityStore = identityStore
        self.clientName = clientName
    }

    public func openRemote(host: String) async throws -> RemoteChannel {
        try await RemoteSession.open(host: host, identity: try identityStore.loadOrCreate())
    }

    public func pairing(host: String) -> PairingChannel {
        LivePairing(host: host, identityStore: identityStore, clientName: clientName)
    }

    /// Sends the magic packet straight to `host`, then also broadcasts it.
    ///
    /// On iPhone, broadcasting needs Apple's multicast entitlement, which a free Apple ID can't get, so the
    /// broadcast usually fails there and that failure is ignored. Errors from the unicast send are thrown.
    public func wake(mac: String, host: String) async throws {
        var unicastError: Error?
        do {
            try await WakeOnLAN.send(mac: mac, to: host)
        } catch {
            unicastError = error
        }
        try? await WakeOnLAN.send(mac: mac)
        if let unicastError { throw unicastError }
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
        let session = PairingSession(host: host, identity: try identityStore.loadOrCreate(), clientName: clientName)
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
