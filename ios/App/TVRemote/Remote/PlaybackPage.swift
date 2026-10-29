import SwiftUI
import TVRemoteKit

/// Skip, seek and play/pause, two pills, and a reminder of the touchpad's gestures.
struct PlaybackPage: View {
    @Environment(ConnectionManager.self) private var connection

    var body: some View {
        VStack(spacing: 0) {
            transport
                .padding(.horizontal, 2)
            pills
                .padding(.top, 40)
            GesturesCard()
                .padding(.top, 14)
        }
    }

    private var transport: some View {
        HStack(spacing: 0) {
            roundButton("backward.end.fill", label: "Previous", key: .previous)
            Spacer(minLength: 8)
            roundButton("gobackward", label: "Back 10 seconds", key: Seek.backward, caption: "10 s")
            Spacer(minLength: 8)
            Button { connection.press(.playPause) } label: {
                Image(systemName: "playpause.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(SheetButtonStyle(shape: Circle(), fill: Theme.accent, pressedFill: Theme.accent.opacity(0.8)))
            .shadow(color: Theme.accent.opacity(0.35), radius: 14, y: 6)
            .accessibilityLabel("Play or pause")
            Spacer(minLength: 8)
            roundButton("goforward", label: "Forward 10 seconds", key: Seek.forward, caption: "10 s")
            Spacer(minLength: 8)
            roundButton("forward.end.fill", label: "Next", key: .next)
        }
    }

    private func roundButton(_ symbol: String, label: String, key: KeyCode, caption: String? = nil) -> some View {
        Button { connection.press(key) } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(SheetButtonStyle(shape: Circle()))
        .overlay(alignment: .bottom) {
            if let caption {
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .offset(y: 20)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(label)
    }

    private var pills: some View {
        HStack(spacing: 10) {
            pill("Subtitles", key: .captions)
            pill("Stop", key: .stop)
        }
    }

    private func pill(_ title: String, key: KeyCode) -> some View {
        Button { connection.press(key) } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(SheetButtonStyle(shape: RoundedRectangle(cornerRadius: 13, style: .continuous)))
    }
}

/// The touchpad's shortcuts, as a short list.
private struct GesturesCard: View {
    private static let rows: [(gesture: String, action: String)] = [
        ("Two-finger tap", "Play / pause"),
        ("Two-finger swipe", "±10 s"),
        ("Right edge, slide", "Volume"),
        ("Press and hold", "Hold OK"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gestures on the touchpad")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Self.rows, id: \.gesture) { row in
                HStack(spacing: 8) {
                    Text(row.gesture)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 8)
                    Text(row.action)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                }
                .lineLimit(1)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
