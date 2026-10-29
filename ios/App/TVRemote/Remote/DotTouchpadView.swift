import SwiftUI
import TVRemoteKit

/// The touchpad: a grid of dim dots that light up orange under the finger and fade behind it.
/// It redraws every frame only while something is lit, and sits still otherwise.
struct DotTouchpadView: View {
    let onCommands: ([RemoteCommand]) -> Void

    @State private var trail = TrailModel()
    @State private var renderer = DotRenderer()

    private static let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(paused: !trail.isLit || trail.isFrozen)) { timeline in
                Canvas { context, size in
                    renderer.draw(in: &context, size: size, trail: trail, now: trail.time(at: timeline.date))
                }
            }
            Text("Swipe to move · Tap to select")
                .font(.system(size: 11))
                .tracking(0.2)
                .foregroundStyle(Theme.hint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.touchpad, in: Capsule())
                .padding(.bottom, 14)
                .opacity(trail.wasTouched ? 0 : 1)
                .animation(.easeOut(duration: 0.5), value: trail.wasTouched)
                .allowsHitTesting(false)
            TouchCaptureView(trail: trail, onCommands: onCommands)
        }
        .background(Theme.touchpad, in: Self.shape)
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(Theme.surface3, lineWidth: 1))
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { size in
            if DemoMode.showsTouchTrail { trail.showDemoTrail(in: size) }
        }
        .accessibilityElement()
        .accessibilityLabel("Touchpad")
        .accessibilityHint("Swipe to move, tap to select.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// Draws the dot grid, the lit dots, and on top the glow at each finger. It keeps the grid's path and the
/// per-dot buffer between frames, so a frame allocates nothing new.
@MainActor
final class DotRenderer {
    private static let spacing: CGFloat = 22
    private static let idleRadius: CGFloat = 1.5
    /// How much bigger a fully lit dot is.
    private static let litGrowth: CGFloat = 1.5
    /// The grid keeps at least this far from the pad's edge; the leftover is split evenly so it sits centred.
    private static let minimumMargin: CGFloat = 14
    private static let glowRadius: CGFloat = 60
    /// Orange at 0.28 under the finger, easing out to nothing at `glowRadius`.
    private static let glow = Gradient(stops: [
        .init(color: Theme.accent.opacity(0.28), location: 0),
        .init(color: Theme.accent.opacity(0.18), location: 0.3),
        .init(color: Theme.accent.opacity(0.07), location: 0.65),
        .init(color: Theme.accent.opacity(0), location: 1),
    ])
    private static let idleShading = GraphicsContext.Shading.color(Theme.idleDot)
    private static let litShading = GraphicsContext.Shading.color(Theme.accent)

    private var size = CGSize.zero
    private var columns = 0
    private var rows = 0
    /// The centre of the top-left dot.
    private var origin = CGPoint.zero
    private var idleDots = Path()
    /// Each dot's intensity this frame, row by row.
    private var intensity: [CGFloat] = []

    func draw(in context: inout GraphicsContext, size: CGSize, trail: TrailModel, now: TimeInterval) {
        layOut(for: size)

        context.fill(idleDots, with: Self.idleShading)
        guard trail.isLit, !intensity.isEmpty else { return }

        light(from: trail, now: now)
        for row in 0..<rows {
            for column in 0..<columns {
                let value = intensity[row * columns + column]
                guard value > 0.005 else { continue }
                let radius = Self.idleRadius + Self.litGrowth * value
                let center = dotCenter(column: column, row: row)
                context.opacity = value
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: Self.litShading
                )
            }
        }

        // The glow goes on top and adds light, so the dots under the finger brighten instead of being tinted.
        context.blendMode = .plusLighter
        trail.forEachGlow(at: now) { location, strength in
            let radius = Self.glowRadius
            context.opacity = strength
            context.fill(
                Path(ellipseIn: CGRect(x: location.x - radius, y: location.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(Self.glow, center: location, startRadius: 0, endRadius: radius)
            )
        }
        context.opacity = 1
        context.blendMode = .normal
    }

    /// Fills `intensity` with the largest `strength · falloff` each dot gets, visiting only the dots in reach.
    private func light(from trail: TrailModel, now: TimeInterval) {
        for index in intensity.indices { intensity[index] = 0 }
        let reach = TrailModel.reach
        trail.forEachSource(at: now) { location, strength in
            let firstColumn = max(0, Int(((location.x - reach - origin.x) / Self.spacing).rounded(.up)))
            let lastColumn = min(columns - 1, Int(((location.x + reach - origin.x) / Self.spacing).rounded(.down)))
            let firstRow = max(0, Int(((location.y - reach - origin.y) / Self.spacing).rounded(.up)))
            let lastRow = min(rows - 1, Int(((location.y + reach - origin.y) / Self.spacing).rounded(.down)))
            guard firstColumn <= lastColumn, firstRow <= lastRow else { return }
            for row in firstRow...lastRow {
                for column in firstColumn...lastColumn {
                    let center = dotCenter(column: column, row: row)
                    let value = strength * TrailModel.falloff(distance: hypot(center.x - location.x, center.y - location.y))
                    let index = row * columns + column
                    if value > intensity[index] { intensity[index] = value }
                }
            }
        }
    }

    private func dotCenter(column: Int, row: Int) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(column) * Self.spacing, y: origin.y + CGFloat(row) * Self.spacing)
    }

    /// Works out the grid for a new size; does nothing while the size stays the same.
    private func layOut(for size: CGSize) {
        guard size != self.size else { return }
        self.size = size
        columns = Self.count(fitting: size.width)
        rows = Self.count(fitting: size.height)
        // Whole points, so every dot lands on the pixel grid the same way and they all look alike.
        origin = CGPoint(
            x: ((size.width - CGFloat(max(columns - 1, 0)) * Self.spacing) / 2).rounded(),
            y: ((size.height - CGFloat(max(rows - 1, 0)) * Self.spacing) / 2).rounded()
        )
        intensity = Array(repeating: 0, count: columns * rows)
        var path = Path()
        let radius = Self.idleRadius
        for row in 0..<rows {
            for column in 0..<columns {
                let center = dotCenter(column: column, row: row)
                path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
        }
        idleDots = path
    }

    private static func count(fitting length: CGFloat) -> Int {
        guard length > minimumMargin * 2 else { return 0 }
        return Int((length - minimumMargin * 2) / spacing) + 1
    }
}
