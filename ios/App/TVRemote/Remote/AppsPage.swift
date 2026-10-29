import SwiftUI
import TVRemoteKit

/// One tap opens an app on the TV. The tiles are plain coloured squares with a text mark, not the apps' logos.
struct AppsPage: View {
    @Environment(ConnectionManager.self) private var connection

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 22) {
            ForEach(AppShortcut.all) { app in
                Button { connection.open(app) } label: {
                    VStack(spacing: 8) {
                        AppTile(app: app)
                        Text(app.name)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.tileLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TileButtonStyle())
                .accessibilityLabel(app.name)
            }
        }
        .padding(.top, 6)
    }
}

/// The 56 pt rounded square of an app.
private struct AppTile: View {
    let app: AppShortcut

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(hex: app.tint))
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            mark
        }
        .frame(width: 56, height: 56)
    }

    @ViewBuilder private var mark: some View {
        switch app.id {
        case "home":
            Image(systemName: "house").font(.system(size: 22, weight: .medium)).foregroundStyle(Theme.text)
        case "all-apps":
            Image(systemName: "square.grid.2x2").font(.system(size: 22, weight: .medium)).foregroundStyle(Theme.text)
        default:
            let text = Self.mark(for: app)
            Text(text.string)
                .font(.system(size: text.size, weight: .heavy))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
        }
    }

    /// The short text on a tile, sized to fit it.
    private static func mark(for app: AppShortcut) -> (string: String, size: CGFloat) {
        switch app.id {
        case "youtube": ("YouTube", 11)
        case "netflix": ("N", 28)
        case "prime-video": ("prime", 14)
        case "apple-tv": ("tv", 20)
        case "disney-plus": ("D+", 20)
        case "youtube-music": ("Music", 12)
        default: (String(app.name.prefix(2)), 18)
        }
    }
}
