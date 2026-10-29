import SwiftUI
import TVRemoteKit

/// Setup screens until a TV is paired, the remote after that.
struct RootView: View {
    @Environment(ConnectionManager.self) private var connection

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch connection.state {
            case .noTV, .needsPairing, .pairing:
                SetupView(target: DemoMode.current?.pairingTarget)
            case .localNetworkDenied:
                LocalNetworkDeniedView()
            case .connecting, .connected, .unreachable:
                RemoteView()
            }
        }
    }
}

// Placeholder until the remote screen exists.

private struct RemoteView: View {
    var body: some View {
        Text("Remote").foregroundStyle(Theme.text)
    }
}
