/// Android key codes the TV accepts through `remote_key_inject`.
public enum KeyCode: Int, CaseIterable {
    case home = 3, back = 4
    case dpadUp = 19, dpadDown = 20, dpadLeft = 21, dpadRight = 22, dpadCenter = 23
    case volumeUp = 24, volumeDown = 25, power = 26
    case enter = 66, del = 67, search = 84
    case playPause = 85, stop = 86, next = 87, previous = 88, rewind = 89, fastForward = 90
    case mute = 164, captions = 175, settings = 176, tvInput = 178
    case hdmi1 = 243, hdmi2 = 244, hdmi3 = 245
    case skipForward = 272, skipBackward = 273, allApps = 284

    /// Short names for the arrows and OK, as typed on the command line.
    private static let aliases: [String: KeyCode] = [
        "UP": .dpadUp, "DOWN": .dpadDown, "LEFT": .dpadLeft, "RIGHT": .dpadRight, "OK": .dpadCenter,
    ]

    /// The command-line name: the case name in upper snake case (`dpadUp` → `DPAD_UP`, `hdmi1` → `HDMI1`).
    public var name: String {
        var name = ""
        for character in String(describing: self) {
            if character.isUppercase { name.append("_") }
            name.append(contentsOf: character.uppercased())
        }
        return name
    }

    /// Looks a key up by its command-line name or one of the aliases `UP DOWN LEFT RIGHT OK`.
    /// Case-insensitive; `-` and `_` are interchangeable.
    public init?(name: String) {
        let key = name.uppercased().replacingOccurrences(of: "-", with: "_")
        if let alias = Self.aliases[key] {
            self = alias
        } else if let match = Self.allCases.first(where: { $0.name == key }) {
            self = match
        } else {
            return nil
        }
    }
}

/// How a key is pressed: a short press, or the two halves of a long press.
public enum KeyDirection: Int {
    case startLong = 1, endLong = 2, short = 3
}

/// The keys that jump about 10 s back or forward in a video.
public enum Seek {
    // unverified on TV — see Task 4 Step 7
    public static let forward: KeyCode = .fastForward
    // unverified on TV — see Task 4 Step 7
    public static let backward: KeyCode = .rewind
}
