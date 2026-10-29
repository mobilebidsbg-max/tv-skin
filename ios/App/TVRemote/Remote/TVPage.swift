import SwiftUI
import TVRemoteKit

/// Input, the three HDMI ports, the TV's settings and search, Power, and Change TV, which forgets this TV (after
/// asking) and goes back to setup.
struct TVPage: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingForget = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            tile("Input", symbol: "tv") { connection.press(.tvInput) }
            tile("HDMI 1", symbol: "cable.connector.horizontal") { connection.press(.hdmi1) }
            tile("HDMI 2", symbol: "cable.connector.horizontal") { connection.press(.hdmi2) }
            tile("HDMI 3", symbol: "cable.connector.horizontal") { connection.press(.hdmi3) }
            tile("Settings", symbol: "gearshape") { connection.press(.settings) }
            tile("Search", symbol: "magnifyingglass") { connection.press(.search) }
            tile("Power", symbol: "power", tint: Theme.accent) { connection.power() }
            tile("Change TV", symbol: "arrow.left.arrow.right") { confirmingForget = true }
                .confirmationDialog(
                    "Forget \(connection.tv?.name ?? "TV")?",
                    isPresented: $confirmingForget,
                    titleVisibility: .visible
                ) {
                    Button("Forget", role: .destructive) {
                        dismiss()
                        connection.forgetTV()
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
        .padding(.top, 6)
    }

    private func tile(_ title: String, symbol: String, tint: Color = Theme.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
                    .background(Theme.surface3, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tileLabel)
                    .lineLimit(1)
            }
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(title)
    }
}
