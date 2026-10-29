import SwiftUI
import TVRemoteKit

/// What the TV last said about its volume, a bar for it, and the three buttons. − and + repeat while held.
struct VolumePage: View {
    @Environment(ConnectionManager.self) private var connection

    var body: some View {
        VStack(spacing: 0) {
            Text(readout)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: readout)
                .accessibilityLabel(readout == "—" ? "Volume unknown" : readout)
            LevelBar(fraction: fraction, isMuted: connection.volume?.muted == true)
                .padding(.top, 14)
            buttons
                .padding(.top, 56)
        }
        .padding(.top, 20)
    }

    /// "Volume 12 of 100", "Muted", or a dash while the TV has not reported.
    private var readout: String {
        guard let volume = connection.volume else { return "—" }
        return volume.muted ? "Muted" : "Volume \(volume.level) of \(volume.max)"
    }

    private var fraction: Double {
        guard let volume = connection.volume, volume.max > 0 else { return 0 }
        return min(max(Double(volume.level) / Double(volume.max), 0), 1)
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            HoldRepeatButton(key: .volumeDown, symbol: "minus", label: "Volume down")
            Spacer(minLength: 12)
            Button { connection.press(.mute) } label: {
                HStack(spacing: 8) {
                    Image(systemName: connection.volume?.muted == true ? "speaker.slash.fill" : "speaker.slash")
                        .font(.system(size: 16, weight: .medium))
                    Text("Mute")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.text)
                .frame(width: 116, height: 56)
            }
            .buttonStyle(SheetButtonStyle(shape: Capsule()))
            Spacer(minLength: 12)
            HoldRepeatButton(key: .volumeUp, symbol: "plus", label: "Volume up")
        }
        .padding(.horizontal, 4)
    }
}

/// A thin track with the level in orange (grey while muted).
private struct LevelBar: View {
    let fraction: Double
    let isMuted: Bool

    var body: some View {
        Capsule()
            .fill(Theme.surface3)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(isMuted ? Theme.hint : Theme.accent)
                        .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 6 : 0))
                }
            }
            .animation(.easeOut(duration: 0.15), value: fraction)
            .accessibilityHidden(true)
    }
}

/// A round volume key. It steps at once when pressed and, like a hardware key, repeats if held (see `HoldRepeater`).
private struct HoldRepeatButton: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(\.scenePhase) private var scenePhase

    let key: KeyCode
    let symbol: String
    let label: String

    @GestureState private var isPressed = false
    @State private var repeater = HoldRepeater()

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(Theme.text)
            .frame(width: 84, height: 84)
            .background(isPressed ? Theme.selected : Theme.surface3, in: Circle())
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
                    .onChanged { _ in press() }
                    .onEnded { _ in repeater.stop() }
            )
            // A touch the system takes away (the sheet is dragged, a call comes in) ends without `onEnded`,
            // but `isPressed` still falls back; so does the button leaving the screen.
            .onChange(of: isPressed) { _, pressed in
                if !pressed { repeater.stop() }
            }
            .onChange(of: scenePhase) { _, _ in repeater.stop() }
            .onDisappear { repeater.stop() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { connection.press(key) }
    }

    private func press() {
        guard !repeater.isHolding else { return }
        Haptics.button()
        let manager = connection
        var steps = 0
        repeater.start { [key] in
            // The first step is the press itself, already tapped; the rest tick.
            if steps > 0 { Haptics.step() }
            steps += 1
            manager.press(key)
        }
    }
}
