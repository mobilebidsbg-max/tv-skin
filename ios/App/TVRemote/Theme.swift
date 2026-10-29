import SwiftUI

/// The app's colours. Orange (`accent`) appears only on touch feedback, play/pause, power and the connection dot.
enum Theme {
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x0A0A0A)
    static let surface2 = Color(hex: 0x141414)
    static let surface3 = Color(hex: 0x1A1A1A)
    static let hairline = Color(hex: 0x222222)
    static let text = Color(hex: 0xF2F2F2)
    static let secondary = Color(hex: 0x8A8A8E)
    /// An unlit dot on the touchpad grid.
    static let idleDot = Color(hex: 0x2C2C2E)
    /// The touchpad's surface, a shade above the background.
    static let touchpad = Color(hex: 0x070707)
    /// The hint on the touchpad.
    static let hint = Color(hex: 0x4A4A4E)
    /// The pull-up handle under the buttons.
    static let grabber = Color(hex: 0x3A3A3C)
    /// The label under the pull-up handle.
    static let grabberLabel = Color(hex: 0x5A5A5E)
    /// The hidden controls sheet.
    static let sheet = Color(hex: 0x0F0F0F)
    /// The chosen tab, and a pressed button in the sheet.
    static let selected = Color(hex: 0x2C2C2E)
    /// Small labels under the sheet's tiles.
    static let tileLabel = Color(hex: 0xB0B0B4)
    /// Claude Code orange.
    static let accent = Color(hex: 0xD97757)
    /// Text and icons on top of `accent`.
    static let onAccent = Color(hex: 0x140A06)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// `#RRGGBB` (the `#` is optional). Anything else is a mid grey.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        self.init(hex: digits.count == 6 ? UInt32(digits, radix: 16) ?? 0x808080 : 0x808080)
    }
}
