import CoreGraphics
import Foundation
import Observation
import QuartzCore

/// Where fingers are and have just been on the touchpad, so the dots under them light up and fade.
///
/// Times are touch timestamps (`UITouch.timestamp`), on the same clock as `CACurrentMediaTime()`. A finger that
/// is down counts as a point of age 0 wherever it is, so a finger held still stays lit. Each point it leaves
/// behind stays lit for `lifetime`.
@MainActor
@Observable
final class TrailModel {
    /// How long a point of the trail stays lit.
    static let lifetime: TimeInterval = 0.6
    /// How far from a point the dots still light up, in points.
    static let reach: CGFloat = 70

    private struct Point {
        let location: CGPoint
        let time: TimeInterval
    }

    /// There is something to draw. The touchpad animates only while this is true.
    private(set) var isLit = false
    /// The trail is a still picture (`-demoTouch`) that does not fade.
    private(set) var isFrozen = false
    /// A finger has touched the pad since it appeared; the hint goes away for good.
    private(set) var wasTouched = false

    /// The trail, oldest first.
    @ObservationIgnored private var points: [Point] = []
    /// Fingers that are down, by touch id.
    @ObservationIgnored private var live: [Int: CGPoint] = [:]
    /// Where fingers left the pad; their glow fades out.
    @ObservationIgnored private var lifts: [Point] = []
    @ObservationIgnored private var frozenTime: TimeInterval?
    /// Turns `isLit` off once the last point has faded.
    @ObservationIgnored private var expiry: Task<Void, Never>?

    init() {
        points.reserveCapacity(256)
        lifts.reserveCapacity(8)
    }

    // MARK: - Touches

    func began(_ id: Int, at location: CGPoint, time: TimeInterval) {
        if isFrozen { unfreeze() }
        expiry?.cancel()
        expiry = nil
        if !wasTouched { wasTouched = true }
        live[id] = location
        append(location, time: time)
    }

    func moved(_ id: Int, to location: CGPoint, time: TimeInterval) {
        guard live[id] != nil else { return }
        live[id] = location
        append(location, time: time)
    }

    func ended(_ id: Int, at location: CGPoint, time: TimeInterval) {
        guard live.removeValue(forKey: id) != nil else { return }
        append(location, time: time)
        lifts.append(Point(location: location, time: time))
        if live.isEmpty { scheduleExpiry() }
    }

    /// Lets every finger go where it is, as if lifted; their dots fade out as usual.
    func cancelAll(time: TimeInterval) {
        guard !live.isEmpty else { return }
        for location in live.values {
            append(location, time: time)
            lifts.append(Point(location: location, time: time))
        }
        live.removeAll(keepingCapacity: true)
        scheduleExpiry()
    }

    // MARK: - Drawing

    /// The trail's clock for the frame shown at `date`: the frozen time, or `CACurrentMediaTime()` then.
    func time(at date: Date) -> TimeInterval {
        frozenTime ?? CACurrentMediaTime() + date.timeIntervalSinceNow
    }

    /// Calls `body` with each point that still lights dots and its strength, `1 − age / lifetime`.
    /// A dot's intensity is the largest `strength · falloff(distance)` over these points.
    func forEachSource(at now: TimeInterval, _ body: (CGPoint, CGFloat) -> Void) {
        for location in live.values { body(location, 1) }
        for point in points {
            let strength = Self.strength(age: now - point.time)
            if strength > 0 { body(point.location, strength) }
        }
    }

    /// Calls `body` with each glow: the fingers that are down at full strength, the ones just lifted fading.
    func forEachGlow(at now: TimeInterval, _ body: (CGPoint, CGFloat) -> Void) {
        for location in live.values { body(location, 1) }
        for lift in lifts {
            let strength = Self.strength(age: now - lift.time)
            if strength > 0 { body(lift.location, strength) }
        }
    }

    /// `1 − age / lifetime`, never below 0. A point from the future (clock jitter) counts as new.
    static func strength(age: TimeInterval) -> CGFloat {
        CGFloat(max(0, 1 - max(age, 0) / lifetime))
    }

    /// `1 − distance / reach`, never below 0.
    static func falloff(distance: CGFloat) -> CGFloat {
        max(0, 1 - distance / reach)
    }

    // MARK: - Demo

    /// A still swipe from left to right across the middle, finger still down at its end, for screenshots
    /// (`-demoTouch`). The first real touch clears it.
    func showDemoTrail(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let now: TimeInterval = 1_000
        expiry?.cancel()
        expiry = nil
        points.removeAll(keepingCapacity: true)
        lifts.removeAll(keepingCapacity: true)
        live.removeAll(keepingCapacity: true)
        let start = CGPoint(x: size.width * 0.2, y: size.height * 0.56)
        let end = CGPoint(x: size.width * 0.66, y: size.height * 0.48)
        let count = 14
        for index in 0..<count {
            let progress = CGFloat(index) / CGFloat(count - 1)
            let location = CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)
            // Oldest at the start of the swipe, about to fade; newest under the finger.
            points.append(Point(location: location, time: now - 0.5 * Double(1 - progress)))
        }
        live[0] = end
        frozenTime = now
        isFrozen = true
        if !wasTouched { wasTouched = true }
        if !isLit { isLit = true }
    }

    // MARK: - Private

    private func append(_ location: CGPoint, time: TimeInterval) {
        prune(now: time)
        points.append(Point(location: location, time: time))
        if !isLit { isLit = true }
    }

    /// Drops what has faded; turns `isLit` off when nothing is left.
    private func prune(now: TimeInterval) {
        guard !isFrozen else { return }
        points.removeAll { now - $0.time >= Self.lifetime }
        lifts.removeAll { now - $0.time >= Self.lifetime }
        if isLit && live.isEmpty && points.isEmpty && lifts.isEmpty { isLit = false }
    }

    /// Prunes once the newest point has faded. Every point is at most as new as now, so one lifetime is enough.
    private func scheduleExpiry() {
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard !Task.isCancelled, let self else { return }
            self.expiry = nil
            self.prune(now: CACurrentMediaTime())
            if self.isLit && self.live.isEmpty { self.scheduleExpiry() }
        }
    }

    private func unfreeze() {
        frozenTime = nil
        isFrozen = false
        points.removeAll(keepingCapacity: true)
        lifts.removeAll(keepingCapacity: true)
        live.removeAll(keepingCapacity: true)
    }
}
