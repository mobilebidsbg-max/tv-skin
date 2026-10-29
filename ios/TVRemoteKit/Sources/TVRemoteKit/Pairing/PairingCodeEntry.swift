/// The text of the pairing code field and the rules for when it counts.
///
/// The field binds to `text`. After every change the view calls `textChanged(during:)`, and after every change
/// of the pairing step `pairingStepChanged(to:)`.
public struct PairingCodeEntry: Equatable {
    public var text = ""

    public init() {}

    /// Whether the TV is waiting for a code: it shows one, and no check is under way.
    public static func accepts(_ step: ConnectionManager.PairingStep?) -> Bool {
        step == .enterCode || step == .wrongCode
    }

    /// Takes the text the field now holds. Text that is not clean (lowercase, a stray character, more than six
    /// characters) is replaced by its clean form, and nothing is submitted; that replacement is a change of
    /// `text` that calls this again. Returns the code to submit once the clean text is a complete code and the
    /// TV is waiting for one.
    public mutating func textChanged(during step: ConnectionManager.PairingStep?) -> String? {
        let clean = PairingCode.sanitize(text)
        guard clean == text else {
            text = clean
            return nil
        }
        guard Self.accepts(step) else { return nil }
        return PairingCode.normalize(clean)
    }

    /// Clears the text when pairing starts over or the last code is spent: a wrong code, a failure, a new
    /// attempt. A code left in the boxes would come back on the next try and be submitted by one more character.
    public mutating func pairingStepChanged(to step: ConnectionManager.PairingStep?) {
        switch step {
        case .connecting, .wrongCode, .failed:
            text = ""
        case .enterCode, .checking, nil:
            break
        }
    }
}
