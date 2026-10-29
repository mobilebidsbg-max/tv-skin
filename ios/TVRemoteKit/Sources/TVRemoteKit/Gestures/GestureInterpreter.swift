import CoreGraphics
import Foundation

/// One finger at one moment. `id` names the finger for the whole touch, `time` is its timestamp in seconds.
public struct TouchSample: Equatable {
    public let id: Int
    public let location: CGPoint
    public let time: TimeInterval

    public init(id: Int, location: CGPoint, time: TimeInterval) {
        self.id = id
        self.location = location
        self.time = time
    }
}

/// What a gesture asks of the TV: a short key press, or the two halves of a long press.
public enum RemoteCommand: Equatable {
    case key(KeyCode)
    case longStart(KeyCode)
    case longEnd(KeyCode)
}

/// The thresholds that turn raw touches into gestures. Distances are in points, speeds in points per second.
public struct GestureConfig: Equatable, Sendable {
    /// Travel along the dominant axis that makes one d-pad step.
    public var stepDistance: CGFloat = 44
    public var tapMaxDuration: TimeInterval = 0.25
    public var tapMaxMovement: CGFloat = 10
    public var longPressDelay: TimeInterval = 0.5
    /// A touch that lands this close to the right edge controls the volume instead of the d-pad.
    public var edgeWidth: CGFloat = 28
    /// Vertical travel that makes one volume step.
    public var volumeStep: CGFloat = 24
    public var twoFingerSwipeDistance: CGFloat = 60
    /// A release faster than `flickVelocity1` adds one extra step, faster than `flickVelocity2` adds two.
    public var flickVelocity1: CGFloat = 1500
    public var flickVelocity2: CGFloat = 2500
    public var maxKeysPerSecond: Int = 20

    public static let `default` = GestureConfig()

    public init(
        stepDistance: CGFloat = 44,
        tapMaxDuration: TimeInterval = 0.25,
        tapMaxMovement: CGFloat = 10,
        longPressDelay: TimeInterval = 0.5,
        edgeWidth: CGFloat = 28,
        volumeStep: CGFloat = 24,
        twoFingerSwipeDistance: CGFloat = 60,
        flickVelocity1: CGFloat = 1500,
        flickVelocity2: CGFloat = 2500,
        maxKeysPerSecond: Int = 20
    ) {
        self.stepDistance = stepDistance
        self.tapMaxDuration = tapMaxDuration
        self.tapMaxMovement = tapMaxMovement
        self.longPressDelay = longPressDelay
        self.edgeWidth = edgeWidth
        self.volumeStep = volumeStep
        self.twoFingerSwipeDistance = twoFingerSwipeDistance
        self.flickVelocity1 = flickVelocity1
        self.flickVelocity2 = flickVelocity2
        self.maxKeysPerSecond = maxKeysPerSecond
    }
}

/// Turns touches on the remote's touchpad into TV commands, the way the Apple TV remote does.
///
/// Coordinates are UIKit-style: origin top left, y grows downward, so moving up is a negative dy.
/// The interpreter holds no timers and is meant for the main thread only: the view feeds it touches and calls
/// `tick(now:)` regularly, with timestamps from the same clock as the touches.
///
/// - One finger: a swipe emits one d-pad key per `stepDistance` and re-anchors; a quick lift adds flick steps;
///   a tap is OK; a still press held for `longPressDelay` is a long OK.
/// - One finger landing within `edgeWidth` of the right edge: moving up or down changes the volume.
/// - Two fingers: a tap is play/pause, a horizontal swipe is one seek. No d-pad keys come out of a two-finger gesture.
public final class GestureInterpreter {
    /// The touchpad size, which decides where the volume edge is. Safe to update when the view is laid out.
    public var size: CGSize
    public let config: GestureConfig

    private enum Mode {
        case idle
        case swipe       // one finger driving the d-pad
        case volume      // one finger that landed on the right edge
        case twoFinger   // stays until every finger is up
    }

    private struct Finger {
        let startLocation: CGPoint
        let startTime: TimeInterval
        var location: CGPoint
        /// Strayed further than `tapMaxMovement` from where it landed, even if it came back.
        var strayed = false
    }

    private struct Pair {
        let first: Int
        let second: Int
        /// When the first of the two fingers landed.
        let startTime: TimeInterval
        /// The fingers' midpoint when the second one landed; the seek swipe is measured from here.
        let baseCentroid: CGPoint
        /// The gesture has had its one result (tap or seek) or can no longer have one.
        var settled = false
    }

    /// Movement inside this window before the release decides whether it was a flick.
    private static let flickWindow: TimeInterval = 0.05
    /// How much of the finger's recent path is kept for that.
    private static let historySpan: TimeInterval = 0.2
    /// Most steps one update may ask for; keeps a wild coordinate from looping for ages.
    private static let maxStepsPerUpdate = 1000

    private var mode = Mode.idle
    private var fingers: [Int: Finger] = [:]
    private var primary: Int?
    private var anchor = CGPoint.zero
    private var recent: [TouchSample] = []
    private var longPressActive = false
    private var pair: Pair?
    private var sentKeyTimes: [TimeInterval] = []

    public init(size: CGSize, config: GestureConfig = .default) {
        self.size = size
        self.config = config
    }

    public func began(_ touches: [TouchSample]) -> [RemoteCommand] {
        var output: [RemoteCommand] = []
        for touch in touches where fingers[touch.id] == nil {
            let finger = Finger(startLocation: touch.location, startTime: touch.time, location: touch.location)
            switch mode {
            case .idle:
                fingers[touch.id] = finger
                primary = touch.id
                anchor = touch.location
                recent = [touch]
                mode = touch.location.x >= size.width - config.edgeWidth ? .volume : .swipe
            case .swipe, .volume:
                guard let first = primary, let firstFinger = fingers[first] else { continue }
                if longPressActive {
                    longPressActive = false
                    output.append(.longEnd(.dpadCenter))
                }
                fingers[touch.id] = finger
                pair = Pair(
                    first: first,
                    second: touch.id,
                    startTime: firstFinger.startTime,
                    baseCentroid: Self.midpoint(firstFinger.location, touch.location)
                )
                primary = nil
                recent = []
                mode = .twoFinger
            case .twoFinger:
                continue   // a third finger does nothing
            }
        }
        return output
    }

    public func moved(_ touches: [TouchSample]) -> [RemoteCommand] {
        touches.flatMap(follow)
    }

    public func ended(_ touches: [TouchSample]) -> [RemoteCommand] {
        var output: [RemoteCommand] = []
        for touch in touches where fingers[touch.id] != nil {
            output += follow(touch)
            output += release(touch)
            fingers[touch.id] = nil
        }
        if fingers.isEmpty { reset() }
        return output
    }

    /// Call regularly (about every 50 ms) while a finger is down; it is what turns a still press into a long press.
    public func tick(now: TimeInterval) -> [RemoteCommand] {
        guard mode == .swipe, !longPressActive,
              let id = primary, let finger = fingers[id], !finger.strayed,
              now - finger.startTime >= config.longPressDelay
        else { return [] }
        longPressActive = true
        return [.longStart(.dpadCenter)]
    }

    /// Forgets every touch, for the system cancelling them. Ends a long press that is still held.
    public func cancelAll() -> [RemoteCommand] {
        let output: [RemoteCommand] = longPressActive ? [.longEnd(.dpadCenter)] : []
        fingers.removeAll()
        reset()
        return output
    }

    // MARK: - Following a finger

    /// Records where a finger is now and returns the commands that movement triggers.
    private func follow(_ touch: TouchSample) -> [RemoteCommand] {
        guard var finger = fingers[touch.id] else { return [] }
        finger.location = touch.location
        if Self.distance(finger.startLocation, touch.location) > config.tapMaxMovement { finger.strayed = true }
        fingers[touch.id] = finger

        switch mode {
        case .idle:
            return []
        case .swipe:
            remember(touch)
            return longPressActive ? [] : swipeSteps(to: touch)
        case .volume:
            return volumeSteps(to: touch)
        case .twoFinger:
            return twoFingerSeek(at: touch.time)
        }
    }

    /// What lifting a finger triggers. `follow` has already applied its final position.
    private func release(_ touch: TouchSample) -> [RemoteCommand] {
        guard let finger = fingers[touch.id] else { return [] }
        switch mode {
        case .idle, .volume:
            return []
        case .swipe:
            if longPressActive {
                longPressActive = false
                return [.longEnd(.dpadCenter)]
            }
            if !finger.strayed && touch.time - finger.startTime <= config.tapMaxDuration {
                return keys(.dpadCenter, count: 1, at: touch.time)
            }
            return flickSteps(endingAt: touch.time)
        case .twoFinger:
            guard var pair, !pair.settled else { return [] }
            pair.settled = true
            self.pair = pair
            let stayedPut = [pair.first, pair.second].allSatisfy { fingers[$0].map { !$0.strayed } ?? false }
            guard stayedPut, touch.time - pair.startTime <= config.tapMaxDuration else { return [] }
            return keys(.playPause, count: 1, at: touch.time)
        }
    }

    private func reset() {
        mode = .idle
        primary = nil
        recent = []
        longPressActive = false
        pair = nil
    }

    // MARK: - One finger

    private func swipeSteps(to touch: TouchSample) -> [RemoteCommand] {
        let dx = touch.location.x - anchor.x
        let dy = touch.location.y - anchor.y
        let horizontal = abs(dx) >= abs(dy)
        let count = stepCount(horizontal ? abs(dx) : abs(dy), step: config.stepDistance)
        guard count > 0 else { return [] }

        // Move the anchor on by the steps taken, so leftover distance counts toward the next step, and drop the
        // sideways drift so a wobbly swipe does not turn into steps on the other axis.
        let travelled = CGFloat(count) * config.stepDistance
        if horizontal {
            anchor = CGPoint(x: anchor.x + (dx > 0 ? travelled : -travelled), y: touch.location.y)
        } else {
            anchor = CGPoint(x: touch.location.x, y: anchor.y + (dy > 0 ? travelled : -travelled))
        }
        return keys(Self.dpadKey(dx: dx, dy: dy), count: count, at: touch.time)
    }

    private func volumeSteps(to touch: TouchSample) -> [RemoteCommand] {
        let dy = touch.location.y - anchor.y
        let count = stepCount(abs(dy), step: config.volumeStep)
        guard count > 0 else { return [] }
        let travelled = CGFloat(count) * config.volumeStep
        anchor.y += dy > 0 ? travelled : -travelled
        return keys(dy < 0 ? .volumeUp : .volumeDown, count: count, at: touch.time)
    }

    /// Extra steps for a quick lift: the finger's speed over the last `flickWindow` seconds before it left.
    private func flickSteps(endingAt time: TimeInterval) -> [RemoteCommand] {
        guard let last = recent.last,
              let first = recent.first(where: { $0.time >= last.time - Self.flickWindow })
        else { return [] }
        let dt = last.time - first.time
        let dx = last.location.x - first.location.x
        let dy = last.location.y - first.location.y
        let length = hypot(dx, dy)
        // A tiny shift in a tiny time is the finger settling as it lifts, not a flick.
        guard dt > 0, length >= config.tapMaxMovement else { return [] }

        let speed = length / dt
        let extra = speed > config.flickVelocity2 ? 2 : (speed > config.flickVelocity1 ? 1 : 0)
        return keys(Self.dpadKey(dx: dx, dy: dy), count: extra, at: time)
    }

    private func remember(_ touch: TouchSample) {
        recent.append(touch)
        recent.removeAll { touch.time - $0.time > Self.historySpan }
    }

    // MARK: - Two fingers

    private func twoFingerSeek(at time: TimeInterval) -> [RemoteCommand] {
        guard var pair, !pair.settled, let a = fingers[pair.first], let b = fingers[pair.second] else { return [] }
        let centroid = Self.midpoint(a.location, b.location)
        let dx = centroid.x - pair.baseCentroid.x
        let dy = centroid.y - pair.baseCentroid.y
        guard abs(dx) > config.twoFingerSwipeDistance, abs(dx) > abs(dy) else { return [] }
        pair.settled = true
        self.pair = pair
        return keys(dx > 0 ? Seek.forward : Seek.backward, count: 1, at: time)
    }

    // MARK: - Output

    /// `count` presses of `key`, minus whatever the rate limit refuses. Refused presses are dropped, not queued.
    private func keys(_ key: KeyCode, count: Int, at time: TimeInterval) -> [RemoteCommand] {
        // Keys sent more than a second ago no longer count.
        sentKeyTimes.removeAll { time - $0 >= 1 }
        let room = max(config.maxKeysPerSecond - sentKeyTimes.count, 0)
        let allowed = min(count, room)
        sentKeyTimes.append(contentsOf: repeatElement(time, count: allowed))
        return Array(repeating: .key(key), count: allowed)
    }

    private func stepCount(_ distance: CGFloat, step: CGFloat) -> Int {
        guard step > 0, distance.isFinite else { return 0 }
        return Int(min(distance / step, CGFloat(Self.maxStepsPerUpdate)))
    }

    private static func dpadKey(dx: CGFloat, dy: CGFloat) -> KeyCode {
        if abs(dx) >= abs(dy) { return dx > 0 ? .dpadRight : .dpadLeft }
        return dy > 0 ? .dpadDown : .dpadUp
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }
}
