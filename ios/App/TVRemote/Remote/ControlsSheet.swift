import SwiftUI
import TVRemoteKit

/// The pages of the hidden controls.
enum ControlsTab: String, CaseIterable, Identifiable {
    case playback, volume, apps, tv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playback: "Playback"
        case .volume: "Volume"
        case .apps: "Apps"
        case .tv: "TV"
        }
    }
}

/// What pulls up from the bottom of the remote: four pages behind a segmented control.
struct ControlsSheet: View {
    @Binding var tab: ControlsTab

    var body: some View {
        VStack(spacing: 0) {
            TabPicker(selection: $tab)
                .padding(.top, 26)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.sheet)
        .presentationCornerRadius(26)
        .onAppear { Haptics.prepare() }
    }

    @ViewBuilder private var page: some View {
        switch tab {
        case .playback: PlaybackPage()
        case .volume: VolumePage()
        case .apps: AppsPage()
        case .tv: TVPage()
        }
    }
}

/// The four tabs in one rounded track; the chosen one is lifted.
private struct TabPicker: View {
    @Binding var selection: ControlsTab
    @Namespace private var lift

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ControlsTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == tab ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.selected)
                                    .matchedGeometryEffect(id: "lift", in: lift)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.surface3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A filled button in the sheet, in whatever shape it is given. It dims a little when pressed and taps back the
/// moment a finger lands.
struct SheetButtonStyle<S: Shape>: ButtonStyle {
    let shape: S
    var fill = Theme.surface3
    var pressedFill = Theme.selected

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedFill : fill, in: shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(shape)
            .hapticOnPressDown(configuration.isPressed)
    }
}

/// A tile that draws its own face. It shrinks and dims a little when pressed and taps back the moment a finger lands.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
            .hapticOnPressDown(configuration.isPressed)
    }
}
