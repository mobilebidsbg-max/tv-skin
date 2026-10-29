import Foundation

/// Repeats an action while a button is held, as a hardware key does: one step the moment it is pressed, then,
/// once `initialDelay` has passed, `rate` more every second until `stop`.
@MainActor
public final class HoldRepeater {
    private let initialDelay: TimeInterval
    private let interval: TimeInterval
    private let wait: (TimeInterval) async -> Void
    private var task: Task<Void, Never>?

    /// Whether a press is under way (started and not yet stopped).
    public var isHolding: Bool { task != nil }

    /// - Parameters:
    ///   - initialDelay: how long a key is held before it starts to repeat.
    ///   - rate: steps per second once repeating.
    ///   - sleep: waits the given number of seconds; tests pass a fake.
    public init(
        initialDelay: TimeInterval = 0.35,
        rate: Int = 8,
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.initialDelay = initialDelay
        interval = 1 / Double(max(rate, 1))
        wait = sleep
    }

    /// Takes one step at once and, if the press lasts, keeps stepping. Does nothing while a press is under way.
    public func start(_ step: @escaping () -> Void) {
        guard task == nil else { return }
        step()
        task = Task { [initialDelay, interval, wait] in
            await wait(initialDelay)
            while !Task.isCancelled {
                step()
                await wait(interval)
            }
        }
    }

    /// Ends the press. Safe to call at any time, and more than once.
    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
