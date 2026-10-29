import SwiftUI
import TVRemoteKit

/// Pairing screens until a TV is paired, the remote after that.
struct RootView: View {
    @Environment(ConnectionManager.self) private var connection

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch connection.state {
            case .noTV, .needsPairing, .pairing:
                SetupView()
            case .connecting, .connected, .unreachable, .localNetworkDenied:
                RemoteView()
            }
        }
    }
}

// Placeholders until the setup and remote screens exist.

private struct SetupView: View {
    var body: some View {
        Text("Setup").foregroundStyle(Theme.text)
    }
}

private struct RemoteView: View {
    var body: some View {
        Text("Remote").foregroundStyle(Theme.text)
    }
}
