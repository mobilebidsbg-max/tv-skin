import XCTest
import TVRemoteKit

final class PairingCodeEntryTests: XCTestCase {
    private typealias Step = ConnectionManager.PairingStep

    /// What the text field does: it now holds `typed`, and the entry is told.
    private func type(_ typed: String, into entry: inout PairingCodeEntry, during step: Step?) -> String? {
        entry.text = typed
        return entry.textChanged(during: step)
    }

    func testACompleteCodeIsSubmittedOnceTheTextIsClean() {
        var entry = PairingCodeEntry()
        XCTAssertNil(type("65a1o2", into: &entry, during: .enterCode), "unclean text is cleaned first")
        XCTAssertEqual(entry.text, "65A102")
        XCTAssertEqual(entry.textChanged(during: .enterCode), "65A102", "the change the cleaning causes submits it")
    }

    func testACleanCompleteCodeIsSubmittedAtOnce() {
        var entry = PairingCodeEntry()
        XCTAssertEqual(type("65A1B2", into: &entry, during: .enterCode), "65A1B2")
        var again = PairingCodeEntry()
        XCTAssertEqual(type("65A1B2", into: &again, during: .wrongCode), "65A1B2")
    }

    func testAPartialCodeIsNotSubmitted() {
        var entry = PairingCodeEntry()
        XCTAssertNil(type("65A", into: &entry, during: .enterCode))
        XCTAssertEqual(entry.text, "65A")
    }

    func testNothingIsSubmittedWhileTheTVIsNotAskingForACode() {
        for step in [Step.connecting, .checking, .failed("x"), nil] {
            var entry = PairingCodeEntry()
            XCTAssertNil(type("65A1B2", into: &entry, during: step), "\(String(describing: step))")
        }
    }

    func testExtraCharactersAreDroppedAndNothingIsSubmittedTwice() {
        var entry = PairingCodeEntry()
        XCTAssertNil(type("65A1B2C", into: &entry, during: .checking))
        XCTAssertEqual(entry.text, "65A1B2")
        XCTAssertNil(entry.textChanged(during: .checking))
    }

    func testOnlyEnterCodeAndWrongCodeAcceptTyping() {
        XCTAssertTrue(PairingCodeEntry.accepts(.enterCode))
        XCTAssertTrue(PairingCodeEntry.accepts(.wrongCode))
        for step in [Step.connecting, .checking, .failed("x"), nil] {
            XCTAssertFalse(PairingCodeEntry.accepts(step), "\(String(describing: step))")
        }
    }

    func testTextIsClearedWhenPairingRestartsOrFails() {
        for step in [Step.wrongCode, .failed("x"), .connecting] {
            var entry = PairingCodeEntry()
            entry.text = "65A1B2"
            entry.pairingStepChanged(to: step)
            XCTAssertEqual(entry.text, "", "\(step)")
        }
    }

    func testTextIsKeptWhileTheTVEntersTheCodeOrChecksIt() {
        for step in [Step.enterCode, .checking] {
            var entry = PairingCodeEntry()
            entry.text = "65A1B2"
            entry.pairingStepChanged(to: step)
            XCTAssertEqual(entry.text, "65A1B2", "\(step)")
        }
    }

    /// A code was submitted, the link dropped, the user tried again: the old code must not come back.
    func testTryAgainAfterAFailureStartsFromAnEmptyCode() {
        var entry = PairingCodeEntry()
        XCTAssertEqual(type("65A1B2", into: &entry, during: .enterCode), "65A1B2")
        entry.pairingStepChanged(to: .checking)
        entry.pairingStepChanged(to: .failed("The TV ended the pairing."))
        entry.pairingStepChanged(to: .connecting)
        entry.pairingStepChanged(to: .enterCode)
        XCTAssertEqual(entry.text, "")
        XCTAssertNil(type("A", into: &entry, during: .enterCode), "one character must not submit the old code")
        XCTAssertEqual(entry.text, "A")
    }
}
