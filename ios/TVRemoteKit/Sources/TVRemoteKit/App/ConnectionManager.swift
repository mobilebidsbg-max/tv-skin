import Foundation
import Observation

/// What the TV last reported about its volume.
public struct VolumeInfo: Equatable {
    public let level: Int
    public let max: Int
    public let muted: Bool

    public init(level: Int, max: Int, muted: Bool) {
        self.level = level
        self.max = max
        self.muted = muted
    }
}

/// The app's connection to its TV: pairing, connecting, reconnecting, and sending what the user does.
///
/// The app reports its lifecycle through `appBecameActive` and `appWentBackground`. While it is active the manager
/// keeps one remote session open. When the TV can't be reached it tries again after 1, 2, 4 and 8 s, then every
/// 10 s. It stops trying when the TV no longer knows this device (`.needsPairing`) or iOS blocks the local network
/// (`.localNetworkDenied`). Commands sent while no session is open are dropped.
@MainActor
@Observable
public final class ConnectionManager {
    public enum State: Equatable {
        /// No TV is paired.
        case noTV
        /// A connection attempt is running or about to start. Also the state in the background, where the
        /// manager waits for `appBecameActive`.
        case connecting
        /// A session is open; `tvOn` says whether the TV's screen is on.
        case connected(tvOn: Bool)
        /// The last attempt failed; the next one follows after a delay.
        case unreachable
        /// The TV rejected this device's certificate: pair again.
        case needsPairing
        case pairing(PairingStep)
        /// iOS blocks the local network. Nothing is retried until the app becomes active again.
        case localNetworkDenied
    }

    public enum PairingStep: Equatable {
        /// Asking the TV to show its code.
        case connecting
        /// The code is on the TV's screen.
        case enterCode
        /// The code was sent; waiting for the TV.
        case checking
        /// The code did not match. The session stays open for another try.
        case wrongCode
        /// Pairing ended; the message says why. Start again to retry.
        case failed(String)
    }

    /// Waits between connection attempts; the last one repeats.
    static let retryDelays: [TimeInterval] = [1, 2, 4, 8, 10]
    /// How long a TV gets after Wake-on-LAN before the next attempt.
    static let wakeDelay: TimeInterval = 3

    public private(set) var state: State
    public private(set) var tv: PairedTV?
    /// nil while no session is open or before the TV has reported it.
    public private(set) var volume: VolumeInfo?
    /// Whether the TV has reported a text field in this session, so `type` can reach it.
    public private(set) var canType = false

    /// The connection attempts and waits that are running, nil when none are. Internal so tests can await it.
    @ObservationIgnored private(set) var connectTask: Task<Void, Never>?

    private let link: TVLinking
    private let store: PairedTVStore
    private let wait: (TimeInterval) async -> Void
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var channel: RemoteChannel?
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var pairing: PairingChannel?
    /// The TV being paired; saved as `tv` once pairing succeeds.
    @ObservationIgnored private var pairingTV: PairedTV?

    /// - Parameter sleep: waits the given number of seconds; tests pass a fake.
    public init(
        link: TVLinking,
        store: PairedTVStore,
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.link = link
        self.store = store
        wait = sleep
        let tv = store.load()
        self.tv = tv
        state = tv == nil ? .noTV : .connecting
    }

    // MARK: - App lifecycle

    /// Connects to the paired TV unless a session is open or an attempt is already running.
    /// Does nothing while the TV needs pairing or pairing is under way.
    public func appBecameActive() {
        isActive = true
        guard connectTask == nil, channel == nil else { return }
        switch state {
        case .connecting, .unreachable:
            startConnecting()
        case .localNetworkDenied:
            // The user may have allowed it in Settings meanwhile; try again.
            if tv == nil {
                state = .noTV
            } else {
                startConnecting()
            }
        case .noTV, .connected, .needsPairing, .pairing:
            break
        }
    }

    /// Closes the session and stops retrying until the app is active again.
    public func appWentBackground() {
        isActive = false
        stopConnecting()
        closeChannel()
        switch state {
        case .connected, .unreachable:
            state = .connecting
        case .noTV, .connecting, .needsPairing, .pairing, .localNetworkDenied:
            break
        }
    }

    // MARK: - Commands

    public func perform(_ command: RemoteCommand) {
        switch command {
        case .key(let key):
            channel?.send(key, .short)
        case .longStart(let key):
            channel?.send(key, .startLong)
        case .longEnd(let key):
            channel?.send(key, .endLong)
        }
    }

    public func press(_ key: KeyCode) {
        channel?.send(key, .short)
    }

    public func open(_ app: AppShortcut) {
        if let appLink = app.link {
            channel?.launch(appLink: appLink)
        } else if let key = app.key {
            press(key)
        }
    }

    /// Replaces the text in the TV's focused text field. Without one, `canType` turns false and nothing is sent.
    public func type(_ text: String) {
        guard let channel else { return }
        do {
            try channel.type(text)
        } catch {
            // The only failure is `.noTextField`.
            canType = false
        }
    }

    /// Toggles the TV while connected. When the TV can't be reached, sends Wake-on-LAN (if its MAC is known) and
    /// tries again 3 s later; without a MAC it simply tries again now.
    public func power() {
        switch state {
        case .connected:
            press(.power)
        case .unreachable:
            if let mac = tv?.mac {
                startConnecting(after: Self.wakeDelay, waking: mac)
            } else {
                startConnecting()
            }
        case .noTV, .connecting, .needsPairing, .pairing, .localNetworkDenied:
            break
        }
    }

    // MARK: - Pairing

    /// Starts pairing with the TV at `host` and returns once its code is on screen (`.pairing(.enterCode)`)
    /// or pairing failed (`.pairing(.failed)`). Ends any session or pairing that was running.
    public func startPairing(host: String, name: String) async {
        endPairing()
        stopConnecting()
        closeChannel()
        let session = link.pairing(host: host)
        pairing = session
        pairingTV = PairedTV(host: host, name: name, mac: PairedTV.knownMACs[host])
        state = .pairing(.connecting)
        do {
            try await session.start()
            guard pairing === session else { return }
            state = .pairing(.enterCode)
        } catch {
            guard pairing === session else { return }
            pairingFailed(error)
        }
    }

    /// Checks the code shown on the TV. A wrong code gives `.pairing(.wrongCode)` and the same session takes
    /// the next try. A right one saves the TV and connects to it.
    public func submitCode(_ code: String) async {
        guard let session = pairing, let candidate = pairingTV,
              state == .pairing(.enterCode) || state == .pairing(.wrongCode)
        else { return }
        state = .pairing(.checking)
        do {
            try await session.finish(code: code)
        } catch {
            guard pairing === session else { return }
            if TVLinkError.map(error, port: TLSChannel.pairingPort) == .badCode {
                state = .pairing(.wrongCode)
            } else {
                pairingFailed(error)
            }
            return
        }
        guard pairing === session else { return }
        pairing = nil
        pairingTV = nil
        tv = candidate
        store.save(candidate)
        state = .connecting
        if isActive { startConnecting() }
    }

    /// Forgets the paired TV: closes the session, stops retrying and pairing, and clears the store.
    public func forgetTV() {
        endPairing()
        stopConnecting()
        closeChannel()
        tv = nil
        store.save(nil)
        state = .noTV
    }

    /// iOS blocks the local network (discovery found out): stop everything until the app is active again.
    public func localNetworkDenied() {
        endPairing()
        stopConnecting()
        closeChannel()
        state = .localNetworkDenied
    }

    // MARK: - Connecting

    /// Replaces any running attempts with a new run of them.
    /// - Parameters:
    ///   - firstDelay: wait before the first attempt; nil tries at once.
    ///   - failures: failures already counted, which picks the delay after the next one.
    ///   - mac: send Wake-on-LAN to this MAC first.
    private func startConnecting(after firstDelay: TimeInterval? = nil, failures: Int = 0, waking mac: String? = nil) {
        stopConnecting()
        guard let host = tv?.host else { return }
        state = .connecting
        connectTask = Task { [weak self] in
            await self?.connect(to: host, after: firstDelay, failures: failures, waking: mac)
        }
    }

    /// Attempts until a session opens, the TV rejects this device, the local network is blocked, or the task is
    /// cancelled. Only the task in `connectTask` runs this: whatever replaces or clears it cancels it first.
    private func connect(to host: String, after firstDelay: TimeInterval?, failures: Int, waking mac: String?) async {
        if let mac {
            // A failed wake is not the end: the TV may wake anyway, or may not have been asleep.
            try? await link.wake(mac: mac, host: host)
        }
        var delay = firstDelay
        var failures = failures
        while true {
            if let delay { await wait(delay) }
            guard !Task.isCancelled else { return }
            state = .connecting
            let channel: RemoteChannel
            do {
                channel = try await link.openRemote(host: host)
            } catch {
                guard !Task.isCancelled else { return }
                switch TVLinkError.map(error, port: TLSChannel.remotePort) {
                case .notPaired:
                    connectTask = nil
                    state = .needsPairing
                    return
                case .localNetworkDenied:
                    connectTask = nil
                    state = .localNetworkDenied
                    return
                default:
                    // TV off, Wi-Fi blip, a dropped handshake: all worth another try.
                    state = .unreachable
                    delay = Self.retryDelays[min(failures, Self.retryDelays.count - 1)]
                    failures += 1
                    continue
                }
            }
            guard !Task.isCancelled else {
                channel.close()
                return
            }
            connectTask = nil
            adopt(channel)
            return
        }
    }

    private func stopConnecting() {
        connectTask?.cancel()
        connectTask = nil
    }

    // MARK: - Session

    /// Makes `channel` the open session and follows its events. Its first event, `.ready`, sets `.connected`.
    private func adopt(_ channel: RemoteChannel) {
        self.channel = channel
        eventsTask = Task { [weak self] in
            for await event in channel.events {
                self?.handle(event, from: channel)
            }
            // In case the stream ends without `.closed`.
            self?.sessionEnded(channel)
        }
    }

    private func handle(_ event: RemoteEvent, from channel: RemoteChannel) {
        guard channel === self.channel else { return }
        switch event {
        case .ready(let isOn), .power(let isOn):
            state = .connected(tvOn: isOn)
        case .volume(let level, let max, let muted):
            volume = VolumeInfo(level: level, max: max, muted: muted)
        case .textField(let available):
            canType = available
        case .currentApp:
            break
        case .closed:
            sessionEnded(channel)
        }
    }

    /// The TV or the network ended the session: start over, waiting 1 s before the first attempt.
    private func sessionEnded(_ channel: RemoteChannel) {
        guard channel === self.channel else { return }
        self.channel = nil
        eventsTask = nil
        volume = nil
        canType = false
        if isActive {
            startConnecting(after: Self.retryDelays[0], failures: 1)
        } else {
            state = .connecting
        }
    }

    /// Closes the open session, if any, without reconnecting.
    private func closeChannel() {
        eventsTask?.cancel()
        eventsTask = nil
        channel?.close()
        channel = nil
        volume = nil
        canType = false
    }

    // MARK: - Pairing helpers

    private func endPairing() {
        pairing?.cancel()
        pairing = nil
        pairingTV = nil
    }

    private func pairingFailed(_ error: Error) {
        endPairing()
        let linkError = TVLinkError.map(error, port: TLSChannel.pairingPort)
        state = linkError == .localNetworkDenied ? .localNetworkDenied : .pairing(.failed(Self.message(for: linkError)))
    }

    private static func message(for error: TVLinkError) -> String {
        switch error {
        case .unreachable:
            return "Can't reach the TV. Is it on and on the same Wi-Fi?"
        case .timeout:
            return "The TV stopped answering."
        case .closed:
            return "The TV ended the pairing."
        case .notPaired, .badCode, .localNetworkDenied, .noTextField, .protocolError:
            return "Pairing didn't work."
        }
    }
}
