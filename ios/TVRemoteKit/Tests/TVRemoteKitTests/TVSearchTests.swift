import Foundation
import XCTest
@testable import TVRemoteKit

private let livingRoom = DiscoveredTV(id: "Living room", name: "Living room", host: "192.168.1.16")

/// `TVSearch` against scripted finders, with a short restart interval and real waits.
@MainActor
final class TVSearchTests: XCTestCase {
    private var finders: [ScriptedFinder] = []
    private var lists: [[DiscoveredTV]] = []
    private var denials = 0

    /// Starts a search whose finders find what `script` says, one entry per finder (nothing after the script).
    private func search(_ script: [[DiscoveredTV]?]) -> Task<Void, Never> {
        var script = script
        return Task {
            await TVSearch.run(
                restartInterval: 0.05,
                makeFinder: {
                    let finder = ScriptedFinder(finds: script.isEmpty ? nil : script.removeFirst())
                    self.finders.append(finder)
                    return finder
                },
                onDenied: { self.denials += 1 },
                onResults: { self.lists.append($0) }
            )
        }
    }

    func testAFinderThatFindsNothingIsReplacedEveryInterval() async {
        let task = search([])

        await waitUntil { self.finders.count >= 3 }
        task.cancel()
        await task.value

        XCTAssertTrue(finders.allSatisfy { $0.started && $0.stopped })
        XCTAssertEqual(lists, [])
    }

    func testAFinderThatFoundATVKeepsRunning() async throws {
        let task = search([[livingRoom]])

        try await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(finders.count, 1)
        XCTAssertFalse(finders[0].stopped)
        XCTAssertEqual(lists, [[livingRoom]])
        task.cancel()
        await task.value
        XCTAssertTrue(finders[0].stopped, "leaving the search stops the finder")
    }

    func testTheFirstFinderToFindATVIsKept() async throws {
        let task = search([nil, nil, [livingRoom]])

        await waitUntil { self.lists == [[livingRoom]] }
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(finders.count, 3)
        XCTAssertEqual(finders.map(\.stopped), [true, true, false])
        task.cancel()
        await task.value
    }

    func testATVThatDisappearsStartsTheRestartsAgain() async {
        let task = search([[livingRoom]])
        await waitUntil { self.finders.count == 1 && self.lists == [[livingRoom]] }

        finders[0].report([])

        await waitUntil { self.finders.count >= 2 }
        XCTAssertTrue(finders[0].stopped)
        task.cancel()
        await task.value
    }

    func testDenialIsPassedOn() async {
        let task = search([])
        await waitUntil { !self.finders.isEmpty }

        finders[0].onPolicyDenied?()

        XCTAssertEqual(denials, 1)
        task.cancel()
        await task.value
    }

    /// Waits (polling every 10 ms) until `condition` holds; fails after 2 s.
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the condition", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// A finder that, once started, reports `finds` (nothing when nil) and then whatever the test reports.
/// Used from the main actor only.
private final class ScriptedFinder: TVFinding {
    let results: AsyncStream<[DiscoveredTV]>
    var onPolicyDenied: (() -> Void)?
    private let continuation: AsyncStream<[DiscoveredTV]>.Continuation
    private let finds: [DiscoveredTV]?
    private(set) var started = false
    private(set) var stopped = false

    init(finds: [DiscoveredTV]?) {
        self.finds = finds
        (results, continuation) = AsyncStream.makeStream(of: [DiscoveredTV].self)
    }

    func start() {
        started = true
        if let finds { continuation.yield(finds) }
    }

    func stop() {
        stopped = true
        continuation.finish()
    }

    func report(_ list: [DiscoveredTV]) {
        continuation.yield(list)
    }
}
