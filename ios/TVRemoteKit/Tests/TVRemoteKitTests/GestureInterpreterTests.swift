import XCTest
import CoreGraphics
import TVRemoteKit

/// Coordinates are UIKit-style (y grows downward) on a 360 x 480 touchpad; times are in seconds.
final class GestureInterpreterTests: XCTestCase {
    private let size = CGSize(width: 360, height: 480)

    private func makeInterpreter(_ configure: (inout GestureConfig) -> Void = { _ in }) -> GestureInterpreter {
        var config = GestureConfig.default
        configure(&config)
        return GestureInterpreter(size: size, config: config)
    }

    private func touch(_ x: CGFloat, _ y: CGFloat, at time: TimeInterval, id: Int = 1) -> TouchSample {
        TouchSample(id: id, location: CGPoint(x: x, y: y), time: time)
    }

    private func keys(_ commands: [RemoteCommand]) -> [KeyCode] {
        commands.compactMap { if case .key(let key) = $0 { return key } else { return nil } }
    }

    // MARK: one-finger swipes

    func testSwipeRightEmitsOneKeyPerStep() {
        let g = makeInterpreter()
        XCTAssertEqual(g.began([touch(100, 200, at: 0)]), [])
        XCTAssertEqual(g.moved([touch(190, 205, at: 0.1)]), [.key(.dpadRight), .key(.dpadRight)])
    }

    func testDiagonalUsesDominantAxis() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(130, 250, at: 0.1)]), [.key(.dpadDown)])
    }

    func testSwipeDirectionsFollowScreenCoordinates() {
        let left = makeInterpreter()
        _ = left.began([touch(200, 240, at: 0)])
        XCTAssertEqual(left.moved([touch(150, 240, at: 0.1)]), [.key(.dpadLeft)])

        let up = makeInterpreter()
        _ = up.began([touch(200, 240, at: 0)])
        XCTAssertEqual(up.moved([touch(200, 190, at: 0.1)]), [.key(.dpadUp)])
    }

    func testMovementBelowStepDistanceEmitsNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(143, 200, at: 0.1)]), [])
    }

    func testLeftoverDistanceCarriesToTheNextStep() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(130, 200, at: 0.1)]), [])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.2)]), [.key(.dpadRight)])   // 50 from the start: anchor now at 144
        XCTAssertEqual(g.moved([touch(180, 200, at: 0.3)]), [])                   // 36 from the anchor
        XCTAssertEqual(g.moved([touch(190, 200, at: 0.4)]), [.key(.dpadRight)])   // 46 from the anchor
    }

    func testReversingDirectionEmitsOppositeKey() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.2)]), [.key(.dpadRight)])
        XCTAssertEqual(g.moved([touch(100, 200, at: 0.4)]), [.key(.dpadLeft)])
    }

    func testSidewaysDriftAfterAStepDoesNotTriggerAnotherAxis() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(150, 230, at: 0.1)]), [.key(.dpadRight)])
        // The 30 pt of vertical drift was dropped with the step, so 20 more is not enough for a vertical step.
        XCTAssertEqual(g.moved([touch(150, 250, at: 0.2)]), [])
    }

    // MARK: tap and long press

    func testTapEmitsCenter() {
        let g = makeInterpreter()
        XCTAssertEqual(g.began([touch(100, 200, at: 0)]), [])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.1)]), [.key(.dpadCenter)])
    }

    func testSmallWobbleStillTaps() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(104, 203, at: 0.05)]), [])
        XCTAssertEqual(g.ended([touch(104, 203, at: 0.1)]), [.key(.dpadCenter)])
    }

    func testPressThatDriftedTooFarIsNotATap() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(115, 200, at: 0.05)]), [])
        XCTAssertEqual(g.ended([touch(115, 200, at: 0.1)]), [])
    }

    func testDriftingAndReturningIsNotATap() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        _ = g.moved([touch(120, 200, at: 0.05)])
        _ = g.moved([touch(100, 200, at: 0.1)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.15)]), [])
    }

    func testSlowReleaseBeforeLongPressDelayIsNotATap() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.4)]), [])
    }

    func testHoldEmitsLongStartThenEnd() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.tick(now: 0.6), [.longStart(.dpadCenter)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.9)]), [.longEnd(.dpadCenter)])
    }

    func testTickBeforeTheDelayEmitsNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.tick(now: 0.4), [])
    }

    func testLongStartIsEmittedOnlyOnce() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.tick(now: 0.5), [.longStart(.dpadCenter)])
        XCTAssertEqual(g.tick(now: 0.6), [])
    }

    func testTickWithoutATouchEmitsNothing() {
        let g = makeInterpreter()
        XCTAssertEqual(g.tick(now: 5), [])
    }

    func testMovedPressIsNotLongPress() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        _ = g.moved([touch(150, 200, at: 0.2)])
        XCTAssertEqual(g.tick(now: 0.6), [])
    }

    func testMovingDuringLongPressEmitsNoKeys() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        _ = g.tick(now: 0.6)
        XCTAssertEqual(g.moved([touch(250, 200, at: 0.7)]), [])
        XCTAssertEqual(g.ended([touch(250, 200, at: 0.8)]), [.longEnd(.dpadCenter)])
    }

    func testCancelAllEndsAnActiveLongPress() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        _ = g.tick(now: 0.6)
        XCTAssertEqual(g.cancelAll(), [.longEnd(.dpadCenter)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.9)]), [])   // the touch is forgotten
        XCTAssertEqual(g.cancelAll(), [])
    }

    func testCancelAllWithoutLongPressIsSilentAndResets() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.cancelAll(), [])
        XCTAssertEqual(g.moved([touch(200, 200, at: 0.1)]), [])
        // A fresh touch works normally afterwards.
        _ = g.began([touch(100, 200, at: 1)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 1.1)]), [.key(.dpadCenter)])
    }

    // MARK: right-edge volume

    func testRightEdgeSlideControlsVolume() {
        let g = makeInterpreter()
        XCTAssertEqual(g.began([touch(345, 300, at: 0)]), [])
        XCTAssertEqual(g.moved([touch(345, 250, at: 0.2)]), [.key(.volumeUp), .key(.volumeUp)])
    }

    func testRightEdgeSlideDownLowersVolume() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        XCTAssertEqual(g.moved([touch(345, 325, at: 0.2)]), [.key(.volumeDown)])
    }

    func testVolumeModeIgnoresHorizontalMovement() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        XCTAssertEqual(g.moved([touch(200, 300, at: 0.2)]), [])
    }

    func testVolumeModeNeverEmitsDpadKeys() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        let all = g.moved([touch(200, 300, at: 0.2)]) + g.moved([touch(200, 100, at: 0.4)])
        XCTAssertEqual(all, [.key(.volumeUp), .key(.volumeUp), .key(.volumeUp), .key(.volumeUp), .key(.volumeUp),
                             .key(.volumeUp), .key(.volumeUp), .key(.volumeUp)])
    }

    func testEdgeBoundaryIsInclusive() {
        let inside = makeInterpreter()
        _ = inside.began([touch(332, 300, at: 0)])      // 360 - 28
        XCTAssertEqual(inside.moved([touch(332, 250, at: 0.2)]), [.key(.volumeUp), .key(.volumeUp)])

        let outside = makeInterpreter()
        _ = outside.began([touch(331, 300, at: 0)])
        XCTAssertEqual(outside.moved([touch(331, 250, at: 0.2)]), [.key(.dpadUp)])
    }

    func testEdgeTapEmitsNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        XCTAssertEqual(g.ended([touch(345, 300, at: 0.1)]), [])
    }

    func testEdgeHoldIsNotALongPress() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        XCTAssertEqual(g.tick(now: 0.6), [])
        XCTAssertEqual(g.ended([touch(345, 300, at: 0.9)]), [])
    }

    func testEdgeFlickDoesNotAddVolumeSteps() {
        let g = makeInterpreter()
        _ = g.began([touch(345, 300, at: 0)])
        XCTAssertEqual(g.moved([touch(345, 250, at: 0.025)]), [.key(.volumeUp), .key(.volumeUp)])
        XCTAssertEqual(g.ended([touch(345, 250, at: 0.025)]), [])
    }

    // MARK: flicks

    func testFastFlickAddsExtraStep() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        let moved = g.moved([touch(150, 200, at: 0.025)])      // 50 pt in 0.025 s = 2000 pt/s
        let ended = g.ended([touch(150, 200, at: 0.025)])
        XCTAssertEqual(moved, [.key(.dpadRight)])
        XCTAssertEqual(ended, [.key(.dpadRight)])
    }

    func testVeryFastFlickAddsTwoExtraSteps() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(200, 200, at: 0.02)]), [.key(.dpadRight), .key(.dpadRight)])   // 5000 pt/s
        XCTAssertEqual(g.ended([touch(200, 200, at: 0.02)]), [.key(.dpadRight), .key(.dpadRight)])
    }

    func testFlickDirectionFollowsTheMovement() {
        let g = makeInterpreter()
        _ = g.began([touch(200, 300, at: 0)])
        XCTAssertEqual(g.moved([touch(200, 250, at: 0.025)]), [.key(.dpadUp)])
        XCTAssertEqual(g.ended([touch(200, 250, at: 0.025)]), [.key(.dpadUp)])
    }

    func testSlowReleaseAddsNoExtraSteps() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.5)]), [.key(.dpadRight)])
        XCTAssertEqual(g.ended([touch(150, 200, at: 0.5)]), [])
    }

    func testRestingBeforeReleaseCancelsTheFlick() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.025)]), [.key(.dpadRight)])
        XCTAssertEqual(g.ended([touch(150, 200, at: 0.3)]), [])
    }

    func testJitterAtLiftOffIsNotAFlick() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.5)]), [.key(.dpadRight)])
        XCTAssertEqual(g.ended([touch(152, 200, at: 0.501)]), [])   // 2000 pt/s, but only 2 pt
    }

    // MARK: two fingers

    func testTwoFingerTapEmitsPlayPause() {
        let g = makeInterpreter()
        XCTAssertEqual(g.began([touch(100, 200, at: 0, id: 1), touch(200, 200, at: 0, id: 2)]), [])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.15, id: 1), touch(200, 200, at: 0.15, id: 2)]), [.key(.playPause)])
    }

    func testTwoFingerTapWithStaggeredLiftEmitsOnce() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1)])
        _ = g.began([touch(200, 200, at: 0.05, id: 2)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.15, id: 1)]), [.key(.playPause)])
        XCTAssertEqual(g.ended([touch(200, 200, at: 0.2, id: 2)]), [])
    }

    func testSlowTwoFingerPressIsNotATap() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1), touch(200, 200, at: 0, id: 2)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.4, id: 1), touch(200, 200, at: 0.4, id: 2)]), [])
    }

    func testTwoFingerSwipeLeftSeeksBackOnce() {
        let g = makeInterpreter()
        _ = g.began([touch(200, 200, at: 0, id: 1), touch(260, 200, at: 0, id: 2)])
        var all = g.moved([touch(110, 200, at: 0.1, id: 1), touch(170, 200, at: 0.1, id: 2)])   // both -90
        all += g.moved([touch(60, 200, at: 0.2, id: 1), touch(120, 200, at: 0.2, id: 2)])       // keeps going
        all += g.ended([touch(60, 200, at: 0.3, id: 1), touch(120, 200, at: 0.3, id: 2)])
        XCTAssertEqual(all, [.key(Seek.backward)])
    }

    func testTwoFingerSwipeRightSeeksForward() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1), touch(160, 200, at: 0, id: 2)])
        var all = g.moved([touch(190, 200, at: 0.1, id: 1), touch(250, 200, at: 0.1, id: 2)])
        all += g.ended([touch(190, 200, at: 0.2, id: 1), touch(250, 200, at: 0.2, id: 2)])
        XCTAssertEqual(all, [.key(Seek.forward)])
    }

    func testTwoFingerSwipeCountsBothFingersAcrossSeparateUpdates() {
        let g = makeInterpreter()
        _ = g.began([touch(200, 200, at: 0, id: 1), touch(260, 200, at: 0, id: 2)])
        XCTAssertEqual(g.moved([touch(110, 200, at: 0.1, id: 1)]), [])   // centroid moved only 45
        XCTAssertEqual(g.moved([touch(170, 200, at: 0.1, id: 2)]), [.key(Seek.backward)])
    }

    func testShortTwoFingerMoveDoesNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(200, 200, at: 0, id: 1), touch(260, 200, at: 0, id: 2)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.1, id: 1), touch(210, 200, at: 0.1, id: 2)]), [])   // -50
        XCTAssertEqual(g.ended([touch(150, 200, at: 0.15, id: 1), touch(210, 200, at: 0.15, id: 2)]), [])   // moved: no tap
    }

    func testVerticalTwoFingerMoveDoesNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(200, 200, at: 0, id: 1), touch(260, 200, at: 0, id: 2)])
        XCTAssertEqual(g.moved([touch(200, 300, at: 0.1, id: 1), touch(260, 300, at: 0.1, id: 2)]), [])
    }

    func testSecondFingerAfterASwipeStillSuppressesDpadKeys() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 0.1, id: 1)]), [.key(.dpadRight)])
        _ = g.began([touch(200, 300, at: 0.15, id: 2)])
        XCTAssertEqual(g.moved([touch(260, 200, at: 0.2, id: 1)]), [])
        XCTAssertEqual(g.ended([touch(260, 200, at: 0.3, id: 1), touch(200, 300, at: 0.3, id: 2)]), [])
    }

    func testSecondFingerCancelsAPendingLongPress() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1)])
        XCTAssertEqual(g.began([touch(200, 200, at: 0.2, id: 2)]), [])
        XCTAssertEqual(g.tick(now: 0.6), [])
    }

    func testSecondFingerEndsAnActiveLongPress() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1)])
        XCTAssertEqual(g.tick(now: 0.6), [.longStart(.dpadCenter)])
        XCTAssertEqual(g.began([touch(200, 200, at: 0.7, id: 2)]), [.longEnd(.dpadCenter)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.9, id: 1), touch(200, 200, at: 0.9, id: 2)]), [])
    }

    func testThirdFingerIsIgnored() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1), touch(200, 200, at: 0, id: 2)])
        XCTAssertEqual(g.began([touch(300, 200, at: 0.05, id: 3)]), [])
        XCTAssertEqual(g.ended([touch(300, 200, at: 0.1, id: 3)]), [])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.15, id: 1), touch(200, 200, at: 0.15, id: 2)]), [.key(.playPause)])
    }

    func testGestureResetsOnceEveryFingerIsUp() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1), touch(200, 200, at: 0, id: 2)])
        _ = g.ended([touch(100, 200, at: 0.1, id: 1), touch(200, 200, at: 0.1, id: 2)])
        _ = g.began([touch(100, 200, at: 1, id: 3)])
        XCTAssertEqual(g.moved([touch(150, 200, at: 1.2, id: 3)]), [.key(.dpadRight)])
    }

    func testRemainingFingerAfterOneLiftsEmitsNothing() {
        let g = makeInterpreter()
        _ = g.began([touch(100, 200, at: 0, id: 1), touch(200, 200, at: 0, id: 2)])
        _ = g.ended([touch(100, 200, at: 0.5, id: 1)])
        XCTAssertEqual(g.moved([touch(300, 200, at: 0.6, id: 2)]), [])
        XCTAssertEqual(g.ended([touch(300, 200, at: 0.7, id: 2)]), [])
    }

    // MARK: rate limit

    private func burst(_ g: GestureInterpreter) -> [RemoteCommand] {
        _ = g.began([touch(0, 200, at: 0)])
        var all: [RemoteCommand] = []
        for i in 1...10 {   // 2000 pt to the right within 0.5 s
            all += g.moved([touch(CGFloat(i) * 200, 200, at: Double(i) * 0.05)])
        }
        return all
    }

    func testBurstIsRateLimited() {
        let g = makeInterpreter { $0.maxKeysPerSecond = 10 }
        let all = burst(g)
        XCTAssertEqual(all.count, 10)
        XCTAssertEqual(Set(keys(all)), [.dpadRight])
    }

    func testDefaultBurstIsCappedAtTwentyKeysPerSecond() {
        XCTAssertEqual(burst(makeInterpreter()).count, 20)
    }

    func testRateLimitWindowRolls() {
        let g = makeInterpreter { $0.maxKeysPerSecond = 10 }
        _ = g.began([touch(0, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(1000, 200, at: 0.1)]).count, 10)   // 22 steps asked for
        XCTAssertEqual(g.moved([touch(1000, 200, at: 0.3)]), [])         // dropped steps are not queued
        XCTAssertEqual(g.moved([touch(1480, 200, at: 1.2)]).count, 10)   // the first keys are over a second old
    }

    func testRateLimitCoversEveryKindOfKey() {
        let g = makeInterpreter { $0.maxKeysPerSecond = 3 }
        _ = g.began([touch(0, 200, at: 0)])
        XCTAssertEqual(g.moved([touch(88, 200, at: 0.1)]).count, 2)
        _ = g.ended([touch(88, 200, at: 0.2)])
        _ = g.began([touch(100, 200, at: 0.3)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.35)]), [.key(.dpadCenter)])   // third key overall
        _ = g.began([touch(100, 200, at: 0.4)])
        XCTAssertEqual(g.ended([touch(100, 200, at: 0.45)]), [])                    // fourth: dropped
    }
}
