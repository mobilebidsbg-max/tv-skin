import Network
import SwiftUI
import TVRemoteKit

/// First run: find the TV on the Wi-Fi (or type its address), then pair with it. Shows the code screen while
/// a pairing is under way.
struct SetupView: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(\.makeTVFinder) private var makeFinder
    @Environment(\.scenePhase) private var scenePhase

    /// The TV being paired, kept for trying again.
    @State private var target: DiscoveredTV?
    @State private var found: [DiscoveredTV] = []
    @State private var address = ""
    /// Bumped to start the search over.
    @State private var searchRun = 0
    /// The app has been active since this screen appeared, so the next activation is a return to it.
    @State private var hasBeenActive = false

    init(target: DiscoveredTV? = nil) {
        _target = State(initialValue: target)
    }

    private var isPairing: Bool {
        if case .pairing = connection.state { return true }
        return false
    }

    var body: some View {
        ZStack {
            if isPairing {
                CodeEntryView(target: target, retry: { pair($0) }, chooseAnother: chooseAnother)
                    .transition(.opacity)
            } else {
                chooser.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPairing)
    }

    // MARK: - Choosing a TV

    private var subtitle: String {
        if connection.state == .needsPairing {
            return "Your TV no longer knows this iPhone. Choose it again to pair."
        }
        return "Your iPhone and TV need to be on the same Wi-Fi."
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SetupHeader(symbol: "tv", title: "Find your TV", subtitle: subtitle)
                if found.isEmpty {
                    searching
                } else {
                    VStack(spacing: 10) {
                        ForEach(found) { tv in
                            TVRow(tv: tv) { pair(tv) }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { addressEntry }
        .task(id: searchRun) { await discover() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            // Back from the Local Network prompt or from Settings: start a search that found nothing over at once.
            if hasBeenActive, found.isEmpty { searchRun += 1 }
            hasBeenActive = true
        }
    }

    private var searching: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Theme.secondary)
            Text("Looking for TVs…")
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var addressEntry: some View {
        HStack(spacing: 8) {
            TextField(
                "IP address",
                text: $address,
                prompt: Text("Enter IP address").foregroundStyle(Theme.secondary)
            )
            .font(.system(size: 17).monospacedDigit())
            .foregroundStyle(Theme.text)
            .keyboardType(.numbersAndPunctuation)
            .autocorrectionDisabled()
            .padding(.leading, 14)
            .onChange(of: address) { _, new in
                let clean = HostAddress.sanitize(new)
                if clean != new { address = clean }
            }
            Button("Connect") { pair(manualTV) }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(IPv4Address(address) == nil)
        }
        .padding(6)
        .surface(radius: 20)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.background)
    }

    /// The TV at the typed address; its name if discovery has found it, otherwise just "TV".
    private var manualTV: DiscoveredTV {
        DiscoveredTV.typed(address, among: found)
    }

    // MARK: - Actions

    /// Looks for TVs for as long as the chooser is on screen, starting over every 5 s while it finds none
    /// ("Looking for TVs…" stays up meanwhile).
    private func discover() async {
        found = []
        let connection = connection
        await TVSearch.run(
            makeFinder: makeFinder,
            onDenied: { Task { @MainActor in connection.localNetworkDenied() } },
            onResults: { found = $0 }
        )
    }

    private func pair(_ tv: DiscoveredTV) {
        target = tv
        Task { await connection.startPairing(host: tv.host, name: tv.name) }
    }

    private func chooseAnother() {
        target = nil
        connection.forgetTV()
    }
}

private struct TVRow: View {
    let tv: DiscoveredTV
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "tv")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface3, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(tv.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(tv.host)
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityLabel("\(tv.name), \(tv.host)")
    }
}

private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .surface(configuration.isPressed ? Theme.surface3 : Theme.surface2)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
