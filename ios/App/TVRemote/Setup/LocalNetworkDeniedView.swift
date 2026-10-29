import SwiftUI
import TVRemoteKit
import UIKit

/// Shown when iOS blocks the local network: nothing can find or reach the TV until the user allows it.
struct LocalNetworkDeniedView: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(\.makeTVFinder) private var makeFinder
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SetupHeader(
                symbol: "wifi.exclamationmark",
                title: "TV Remote needs Local Network access to find your TV.",
                subtitle: "Switch on Local Network for TV Remote, then come back.",
                isSentence: true
            )
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 36)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await recoverWhenAllowed() }
    }

    /// Browses while this screen is up. The first TV that turns up means access was granted (for example from
    /// the system prompt, which does not bring the app back to the foreground), so the connection starts over.
    private func recoverWhenAllowed() async {
        let finder = makeFinder()
        finder.start()
        defer { finder.stop() }
        for await list in finder.results where !list.isEmpty {
            connection.appBecameActive()
            return
        }
    }
}
