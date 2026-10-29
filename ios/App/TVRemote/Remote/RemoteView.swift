import SwiftUI
import TVRemoteKit

/// The remote: header, the dotted touchpad, four buttons, and the handle that pulls up the hidden controls.
struct RemoteView: View {
    @Environment(ConnectionManager.self) private var connection

    @State var showControls = DemoMode.sheetTab != nil
    @State var showKeyboard = DemoMode.showsKeyboard
    /// The page the controls were last on; the sheet opens there again.
    @State private var controlsTab = DemoMode.sheetTab ?? .playback

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding(.leading, 22)
                .padding(.trailing, 16)
                .padding(.top, 6)
            DotTouchpadView(onCommands: perform)
                .padding(.horizontal, 16)
                .padding(.top, 18)
            buttons
                .padding(.horizontal, 30)
                .padding(.top, 28)
            ControlsHandle(open: openControls)
                .padding(.top, 14)
        }
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $showControls) {
            ControlsSheet(tab: $controlsTab)
        }
        .sheet(isPresented: $showKeyboard) {
            KeyboardSheet()
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            RemoteButton(symbol: "chevron.left", label: "Back", weight: .semibold) { connection.press(.back) }
            Spacer(minLength: 12)
            RemoteButton(symbol: "house", label: "Home") { connection.press(.home) }
            Spacer(minLength: 12)
            RemoteButton(symbol: "playpause.fill", label: "Play/Pause", tint: Theme.accent) { connection.press(.playPause) }
            Spacer(minLength: 12)
            RemoteButton(symbol: "keyboard", label: "Keyboard", size: 18) { showKeyboard = true }
        }
    }

    /// Touchpad commands go to the TV, each kind with its own tap.
    private func perform(_ commands: [RemoteCommand]) {
        Haptics.play(commands)
        for command in commands { connection.perform(command) }
    }

    private func openControls() {
        guard !showControls else { return }
        Haptics.button()
        showControls = true
    }
}

/// A 56 pt round button in the row under the touchpad.
private struct RemoteButton: View {
    let symbol: String
    let label: String
    var tint = Theme.text
    /// Size and weight even out how heavy the glyphs look next to each other.
    var size: CGFloat = 20
    var weight: Font.Weight = .medium
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(tint)
        }
        .buttonStyle(RoundButtonStyle(diameter: 56))
        .accessibilityLabel(label)
    }
}

/// The pill and "Controls" under the buttons. A tap or a swipe up opens the hidden controls.
private struct ControlsHandle: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 5) {
                Capsule()
                    .fill(Theme.grabber)
                    .frame(width: 36, height: 5)
                Text("Controls")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.grabberLabel)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8).onEnded { drag in
                if drag.translation.height < -16 { open() }
            }
        )
        .accessibilityLabel("Controls")
        .accessibilityHint("Shows playback, volume, apps and TV controls.")
    }
}

/// A dark round button with a hairline edge. It taps back and dims slightly the moment a finger lands.
struct RoundButtonStyle: ButtonStyle {
    let diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(configuration.isPressed ? Theme.surface3 : Theme.surface2, in: Circle())
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
            .hapticOnPressDown()
    }
}
