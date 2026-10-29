import SwiftUI
import TVRemoteKit
import UIKit

/// The top of the remote: the TV's name, the state of the connection under it, and the power button.
struct HeaderView: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(\.openURL) private var openURL

    var body: some View {
        let status = ConnectionStatus(connection.state)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(connection.tv?.name ?? "TV")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if status.opensSettings {
                    Button(action: openSettings) { StatusLine(status: status) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Settings")
                } else {
                    StatusLine(status: status)
                }
            }
            Spacer(minLength: 8)
            Button {
                connection.power()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(RoundButtonStyle(diameter: 40))
            .accessibilityLabel("Power")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// What the line under the TV's name says for a connection state.
struct ConnectionStatus: Equatable {
    let text: String
    /// The dot is orange: connected and the TV is on.
    var isLive = false
    /// The dot pulses while a connection is being made.
    var isPending = false
    /// Tapping the line opens Settings.
    var opensSettings = false

    init(_ state: ConnectionManager.State) {
        switch state {
        case .connected(tvOn: true):
            text = "Connected"
            isLive = true
        case .connected(tvOn: false):
            text = "TV is off"
        case .connecting:
            text = "Connecting…"
            isPending = true
        case .unreachable:
            text = "Can't reach the TV"
        case .localNetworkDenied:
            text = "Local Network is off"
            opensSettings = true
        case .noTV, .needsPairing, .pairing:
            // The remote is not on screen in these states.
            text = "Not connected"
        }
    }
}

private struct StatusLine: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(isLive: status.isLive, isPending: status.isPending)
            Text(status.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
            if status.opensSettings {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: status)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The 6 pt dot: orange with a soft glow when live, grey otherwise, breathing while connecting.
private struct StatusDot: View {
    let isLive: Bool
    let isPending: Bool
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(isLive ? Theme.accent : Theme.secondary)
            .frame(width: 6, height: 6)
            .shadow(color: Theme.accent.opacity(isLive ? 0.9 : 0), radius: 3)
            .opacity(isDimmed ? 0.3 : 1)
            .animation(
                isPending ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .easeOut(duration: 0.2),
                value: isDimmed
            )
            .onChange(of: isPending, initial: true) { _, pending in isDimmed = pending }
            .accessibilityHidden(true)
    }
}
