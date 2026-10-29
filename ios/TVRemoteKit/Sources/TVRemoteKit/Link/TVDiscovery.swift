import Foundation
import Network

/// A TV found on the local network.
public struct DiscoveredTV: Identifiable, Equatable, Sendable {
    /// The name of its Bonjour service, which the network keeps unique.
    public let id: String
    public let name: String
    /// Its IP address.
    public let host: String

    public init(id: String, name: String, host: String) {
        self.id = id
        self.name = name
        self.host = host
    }
}

/// Finds TVs, as the setup screen uses it; the app's demo mode swaps in a fake.
public protocol TVFinding: AnyObject {
    /// The TVs found so far, sent again whenever the list changes. Ends when the finder is stopped.
    var results: AsyncStream<[DiscoveredTV]> { get }
    /// Called, on an arbitrary queue, when iOS blocks the local network.
    var onPolicyDenied: (() -> Void)? { get set }
    func start()
    func stop()
}

/// Finds Google TVs that advertise `_androidtvremote2._tcp` on the local network (Bonjour).
///
/// Each TV found is resolved to its IP address by opening a short connection to it. A discovery works once:
/// after `stop()` it stays finished.
public final class TVDiscovery: TVFinding, @unchecked Sendable {
    public static let serviceType = "_androidtvremote2._tcp"

    /// The DNS-SD error iOS reports when the user has not allowed local network access (`kDNSServiceErr_PolicyDenied`).
    private static let policyDeniedCode: Int32 = -65570
    /// How long an attempt to resolve a TV's address may take, and how long to wait before the next one. A TV
    /// that answers slowly is often answered at once by a fresh attempt, so attempts are short.
    private static let resolveTimeout: TimeInterval = 2
    private static let retryDelay: TimeInterval = 0.5
    private static let maxAttempts = 6

    public let results: AsyncStream<[DiscoveredTV]>

    /// Guarded by `lock`: set from the main thread, read on `queue`.
    private let lock = NSLock()
    private var denialHandler: (() -> Void)?

    public var onPolicyDenied: (() -> Void)? {
        get { lock.withLock { denialHandler } }
        set { lock.withLock { denialHandler = newValue } }
    }

    private let continuation: AsyncStream<[DiscoveredTV]>.Continuation
    private let queue = DispatchQueue(label: "tvremote.discovery")

    // Everything below is only touched on `queue`.
    private var browser: NWBrowser?
    private var services: [String: Service] = [:]
    private var published: [DiscoveredTV] = []
    private var stopped = false
    private var denialReported = false

    private struct Service {
        let endpoint: NWEndpoint
        var host: String?
        var connection: NWConnection?
    }

    public init() {
        (results, continuation) = AsyncStream.makeStream(of: [DiscoveredTV].self, bufferingPolicy: .bufferingNewest(1))
    }

    deinit {
        browser?.cancel()
        services.values.forEach { $0.connection?.cancel() }
        continuation.finish()
    }

    public func start() {
        queue.async { [self] in
            guard !stopped, browser == nil else { return }
            let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
            browser.stateUpdateHandler = { [weak self] state in self?.browserStateChanged(state) }
            browser.browseResultsChangedHandler = { [weak self] results, _ in self?.browseResultsChanged(results) }
            self.browser = browser
            browser.start(queue: queue)
        }
    }

    /// Stops browsing and ends `results`. Calling it again does nothing.
    public func stop() {
        queue.async { [self] in
            guard !stopped else { return }
            stopped = true
            browser?.cancel()
            browser = nil
            services.values.forEach { $0.connection?.cancel() }
            services = [:]
            continuation.finish()
        }
    }

    // MARK: - Browsing

    private func browserStateChanged(_ state: NWBrowser.State) {
        switch state {
        case .waiting(let error), .failed(let error):
            if Self.isPolicyDenied(error) { reportDenial() }
        case .setup, .ready, .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func browseResultsChanged(_ found: Set<NWBrowser.Result>) {
        guard !stopped else { return }
        var present: [String: NWEndpoint] = [:]
        for result in found {
            // The same TV can show up once per network interface; the first one is enough.
            if case .service(let name, _, _, _) = result.endpoint, present[name] == nil {
                present[name] = result.endpoint
            }
        }
        for name in services.keys where present[name] == nil {
            services[name]?.connection?.cancel()
            services[name] = nil
        }
        for (name, endpoint) in present where services[name] == nil {
            services[name] = Service(endpoint: endpoint)
            resolve(name, attempt: 0)
        }
        publish()
    }

    private func reportDenial() {
        guard !stopped, !denialReported else { return }
        denialReported = true
        onPolicyDenied?()
    }

    // MARK: - Resolving

    /// Finds the IP address of a TV by connecting to its service and reading where the connection went.
    private func resolve(_ name: String, attempt: Int) {
        guard !stopped, let service = services[name], service.host == nil else { return }
        let parameters = NWParameters.tcp
        // The remote protocol is used over IPv4, so that comes first; every other attempt takes any address.
        if attempt.isMultiple(of: 2), let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: service.endpoint, using: parameters)
        services[name]?.connection = connection

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.resolved(name, by: connection)
            case .waiting(let error), .failed(let error):
                if Self.isPolicyDenied(error) { self.reportDenial() }
                if case .failed = state { self.retry(name, after: connection, attempt: attempt) }
            case .setup, .preparing, .cancelled:
                break
            @unknown default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.resolveTimeout) { [weak self, weak connection] in
            guard let self, let connection else { return }
            self.retry(name, after: connection, attempt: attempt)
        }
    }

    private func resolved(_ name: String, by connection: NWConnection) {
        defer { connection.cancel() }
        guard services[name]?.connection === connection,
              case .hostPort(let host, _)? = connection.currentPath?.remoteEndpoint
        else { return }
        services[name]?.host = Self.hostString(host)
        services[name]?.connection = nil
        publish()
    }

    /// Gives up on `connection` if it is still the one resolving `name`, and starts the next attempt.
    private func retry(_ name: String, after connection: NWConnection, attempt: Int) {
        guard services[name]?.connection === connection else { return }
        connection.cancel()
        services[name]?.connection = nil
        guard attempt + 1 < Self.maxAttempts else { return }
        queue.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in
            self?.resolve(name, attempt: attempt + 1)
        }
    }

    private func publish() {
        let list = Self.list(from: services.mapValues(\.host))
        guard list != published else { return }
        published = list
        continuation.yield(list)
    }

    // MARK: - Pure helpers

    static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == policyDeniedCode }
        return false
    }

    /// The address as text: dotted for IPv4, and for names or IPv6 whatever Network calls them.
    static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address):
            return address.rawValue.map(String.init).joined(separator: ".")
        case .ipv6(let address):
            return address.debugDescription
        case .name(let name, _):
            return name
        @unknown default:
            return "\(host)"
        }
    }

    /// The TVs whose address is known, by name.
    static func list(from hosts: [String: String?]) -> [DiscoveredTV] {
        hosts
            .compactMap { name, host in host.map { DiscoveredTV(id: name, name: name, host: $0) } }
            .sorted { $0.name == $1.name ? $0.host < $1.host : $0.name < $1.name }
    }
}
