import TVRemoteKit
import UIKit

/// What the iPhone taps back. The generators are made once and kept; in the Simulator they do nothing.
@MainActor
enum Haptics {
    enum Feel {
        case light, medium, rigid, selection, soft
    }

    /// The feel of a touchpad command, nil for none: a d-pad step is light, OK medium, the start of a long press
    /// rigid, a volume step a selection tick, play/pause (and seeking) soft.
    static func feel(for command: RemoteCommand) -> Feel? {
        switch command {
        case .key(.dpadUp), .key(.dpadDown), .key(.dpadLeft), .key(.dpadRight):
            return .light
        case .key(.dpadCenter):
            return .medium
        case .longStart:
            return .rigid
        case .key(.volumeUp), .key(.volumeDown):
            return .selection
        case .key:
            return .soft
        case .longEnd:
            return nil
        }
    }

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()

    /// Wakes the Taptic Engine so the next tap comes without delay. Call when a finger lands.
    static func prepare() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
        soft.prepare()
        selection.prepare()
    }

    /// One tap per feel in `commands`; the extra steps of a flick share a tap.
    static func play(_ commands: [RemoteCommand]) {
        var played: Set<Feel> = []
        for command in commands {
            guard let feel = feel(for: command), played.insert(feel).inserted else { continue }
            play(feel)
        }
    }

    /// A button on the remote.
    static func button() {
        play(.soft)
    }

    private static func play(_ feel: Feel) {
        switch feel {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .rigid: rigid.impactOccurred()
        case .soft: soft.impactOccurred()
        case .selection: selection.selectionChanged()
        }
    }
}
