import Foundation
import XCTest
@testable import TVRemoteKit

/// `HoldRepeater` against a clock the test winds by hand: a wait lasts until `release()` ends it.
@MainActor
final class HoldRepeaterTests: XCTestCase {
    private var clock: HandClock!
    private var steps = 0

    override func tearDown() async throws {
        clock?.releaseAll()
    }

    private func makeRepeater() -> HoldRepeater {
        steps = 0
        clock = HandClock()
        let clock = clock!
        return HoldRepeater(sleep: { await clock.sleep($0) })
    }

    private func start(_ repeater: HoldRepeater) {
        repeater.start { [unowned self] in steps += 1 }
    }

    func testOnePressIsOneStepAtOnce() async {
        let repeater = makeRepeater()
        start(repeater)
        XCTAssertEqual(steps, 1)
        XCTAssertTrue(repeater.isHolding)
        repeater.stop()
        XCTAssertFalse(repeater.isHolding)
        await clock.settle()
        XCTAssertEqual(steps, 1)
    }

    func testRepeatsAfterTheInitialDelayEightTimesASecond() async {
        let repeater = makeRepeater()
        start(repeater)
        await clock.waitForSleep(count: 1)
        XCTAssertEqual(clock.delays, [0.35])
        XCTAssertEqual(steps, 1, "nothing repeats before the delay is over")

        clock.release()
        await clock.waitForSleep(count: 2)
        XCTAssertEqual(steps, 2)
        clock.release()
        await clock.waitForSleep(count: 3)
        XCTAssertEqual(steps, 3)
        XCTAssertEqual(clock.delays, [0.35, 0.125, 0.125])
        repeater.stop()
    }

    func testStopEndsTheRepeatingEvenWhileAWaitIsRunning() async {
        let repeater = makeRepeater()
        start(repeater)
        await clock.waitForSleep(count: 1)
        clock.release()
        await clock.waitForSleep(count: 2)
        XCTAssertEqual(steps, 2)

        repeater.stop()
        clock.release()
        await clock.settle()
        XCTAssertEqual(steps, 2)
        XCTAssertEqual(clock.delays.count, 2, "no wait begins after the stop")
    }

    func testStopBeforeTheInitialDelayIsOverRepeatsNothing() async {
        let repeater = makeRepeater()
        start(repeater)
        await clock.waitForSleep(count: 1)
        repeater.stop()
        clock.release()
        await clock.settle()
        XCTAssertEqual(steps, 1)
    }

    func testStartWhileHoldingDoesNotStepAgain() async {
        let repeater = makeRepeater()
        start(repeater)
        start(repeater)
        XCTAssertEqual(steps, 1)
        repeater.stop()
    }

    func testCanBePressAgainAfterAStop() async {
        let repeater = makeRepeater()
        start(repeater)
        repeater.stop()
        start(repeater)
        XCTAssertEqual(steps, 2)
        await clock.waitForSleep(count: 2)
        XCTAssertEqual(clock.delays.last, 0.35, "a new press starts with the initial delay again")
        repeater.stop()
    }

    func testStopWithoutAPressDoesNothing() {
        let repeater = makeRepeater()
        repeater.stop()
        XCTAssertFalse(repeater.isHolding)
    }
}

/// Records every wait and holds each one until `release()`; a cancelled wait ends by itself.
@MainActor
private final class HandClock {
    private(set) var delays: [TimeInterval] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func sleep(_ delay: TimeInterval) async {
        delays.append(delay)
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Ends the oldest wait that is still running.
    func release() {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst().resume()
    }

    /// Ends every wait, so no test leaves a task hanging.
    func releaseAll() {
        while !waiting.isEmpty { release() }
    }

    func waitForSleep(count: Int) async {
        for _ in 0..<1000 where delays.count < count {
            await Task.yield()
        }
        XCTAssertGreaterThanOrEqual(delays.count, count)
    }

    /// Lets whatever is queued run.
    func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }
}
