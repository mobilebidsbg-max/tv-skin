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
    /// Claude Code orange.
    static let accent = Color(hex: 0xD97757)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
