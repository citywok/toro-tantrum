import XCTest
@testable import NoNoNo

final class TargetKindTests: XCTestCase {

    func testKindsPartitionIntoRageAndAloha() {
        XCTAssertFalse(TargetKind.rageKinds.isEmpty)
        XCTAssertFalse(TargetKind.alohaKinds.isEmpty)
        XCTAssertEqual(TargetKind.rageKinds.count + TargetKind.alohaKinds.count,
                       TargetKind.allCases.count)
    }

    func testRageTargetsScorePointsAndAlohaDoNot() {
        for kind in TargetKind.rageKinds {
            XCTAssertGreaterThan(kind.points, 0, "\(kind) should score points")
        }
        for kind in TargetKind.alohaKinds {
            XCTAssertEqual(kind.points, 0, "\(kind) should not score points")
        }
    }

    func testEveryKindHasEmojiAndLabel() {
        for kind in TargetKind.allCases {
            XCTAssertFalse(kind.emoji.isEmpty)
            XCTAssertFalse(kind.label.isEmpty)
        }
    }

    func testOnionAndWasabiAreTheJackpot() {
        XCTAssertEqual(TargetKind.rageKinds.max(by: { $0.points < $1.points })?.points,
                       TargetKind.onion.points,
                       "onion denial stays top-tier")
    }

    func testHateListTargetsHaveCaptionsAndAlohaDoNot() {
        for kind in [TargetKind.onion, .cucumber, .tomato, .wasabi] {
            XCTAssertTrue(kind.isRage)
            XCTAssertNotNil(kind.caption, "\(kind) needs its caption to land the joke")
        }
        for kind in TargetKind.alohaKinds {
            XCTAssertNil(kind.caption)
        }
    }
}
