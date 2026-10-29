import QuartzCore
import SwiftUI
import TVRemoteKit
import UIKit

/// Takes the raw touches on the touchpad. They go to a `GestureInterpreter`, whose commands go to `onCommands`,
/// and to the trail that lights the dots.
struct TouchCaptureView: UIViewRepresentable {
    let trail: TrailModel
    let onCommands: ([RemoteCommand]) -> Void

    func makeUIView(context: Context) -> TouchSurface {
        TouchSurface(trail: trail, onCommands: onCommands)
    }

    func updateUIView(_ surface: TouchSurface, context: Context) {
        surface.onCommands = onCommands
    }

    static func dismantleUIView(_ surface: TouchSurface, coordinator: ()) {
        surface.cancelTouches()
    }
}

/// The UIKit view under the fingers. Touch timestamps and `tick(now:)` both use the media clock
/// (`UITouch.timestamp`, `CACurrentMediaTime()`). A display link ticks the interpreter every frame while a finger
/// is down, which is what turns a still press into a long press, and stops when the last finger lifts.
final class TouchSurface: UIView {
    var onCommands: ([RemoteCommand]) -> Void

    private let trail: TrailModel
    private let interpreter = GestureInterpreter(size: .zero)
    private var displayLink: CADisplayLink?
    /// The touches that are down.
    private var down: Set<ObjectIdentifier> = []

    init(trail: TrailModel, onCommands: @escaping ([RemoteCommand]) -> Void) {
        self.trail = trail
        self.onCommands = onCommands
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        interpreter.size = bounds.size
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelTouches() }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        Haptics.prepare()
        var samples: [TouchSample] = []
        for touch in touches {
            down.insert(ObjectIdentifier(touch))
            let sample = Self.sample(of: touch, id: Self.id(of: touch), in: self)
            samples.append(sample)
            trail.began(sample.id, at: sample.location, time: sample.time)
        }
        send(interpreter.began(samples))
        if !down.isEmpty { startTicking() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var samples: [TouchSample] = []
        for touch in touches {
            let id = Self.id(of: touch)
            // Coalesced touches carry the positions between frames; they are separate objects, so the id comes
            // from the touch they belong to.
            for step in event?.coalescedTouches(for: touch) ?? [touch] {
                let sample = Self.sample(of: step, id: id, in: self)
                samples.append(sample)
                trail.moved(id, to: sample.location, time: sample.time)
            }
        }
        send(interpreter.moved(samples))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        var samples: [TouchSample] = []
        for touch in touches {
            down.remove(ObjectIdentifier(touch))
            let sample = Self.sample(of: touch, id: Self.id(of: touch), in: self)
            samples.append(sample)
            trail.ended(sample.id, at: sample.location, time: sample.time)
        }
        send(interpreter.ended(samples))
        if down.isEmpty { stopTicking() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelTouches()
    }

    /// Forgets every finger: ends a long press that is still held and lets the trail fade.
    func cancelTouches() {
        stopTicking()
        down.removeAll()
        send(interpreter.cancelAll())
        trail.cancelAll(time: CACurrentMediaTime())
    }

    @objc private func appWillResignActive() {
        cancelTouches()
    }

    // MARK: - Ticking

    private func startTicking() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTicking() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        send(interpreter.tick(now: CACurrentMediaTime()))
    }

    // MARK: - Helpers

    private func send(_ commands: [RemoteCommand]) {
        guard !commands.isEmpty else { return }
        onCommands(commands)
    }

    /// The same number for a touch from the moment it lands until it lifts.
    private static func id(of touch: UITouch) -> Int {
        Int(bitPattern: ObjectIdentifier(touch))
    }

    private static func sample(of touch: UITouch, id: Int, in view: UIView) -> TouchSample {
        TouchSample(id: id, location: touch.location(in: view), time: touch.timestamp)
    }
}
