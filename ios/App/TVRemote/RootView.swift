import SwiftUI
import TVRemoteKit

/// Setup screens until a TV is paired, the remote after that. With a paired TV the remote stays up when iOS blocks
/// the local network, and its header says so.
struct RootView: View {
    @Environment(ConnectionManager.self) private var connection

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch connection.state {
            case .noTV, .needsPairing, .pairing:
                SetupView(target: DemoMode.current?.pairingTarget)
            case .localNetworkDenied where connection.tv == nil:
                LocalNetworkDeniedView()
            case .connecting, .connected, .unreachable, .localNetworkDenied:
                RemoteView()
            }
        }
    }
}
