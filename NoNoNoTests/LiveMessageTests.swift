import XCTest
@testable import NoNoNo

final class LiveMessageTests: XCTestCase {

    private func roundTrip(_ message: LiveMessage) {
        guard let data = message.encoded() else {
            return XCTFail("failed to encode \(message)")
        }
        XCTAssertEqual(LiveMessage.decode(data), message)
    }

    func testAllMessagesRoundTrip() {
        roundTrip(.hello(name: "PLAYER"))
        roundTrip(.roster(names: ["PLAYER", "KYLE", "PAT"]))
        roundTrip(.start(seed: 12345, delay: 3))
        roundTrip(.score(name: "KYLE", score: 420))
        roundTrip(.smashed(name: "PLAYER"))
        roundTrip(.demand(id: UUID(), kindRaw: TargetKind.onion.rawValue,
                          player: "PAT", window: 6))
        roundTrip(.demandResult(id: UUID(), player: "PAT", fulfilled: false))
        roundTrip(.finalScore(name: "PLAYER", score: 999))
    }

    func testGarbageDataDecodesToNil() {
        XCTAssertNil(LiveMessage.decode(Data("not json".utf8)))
        XCTAssertNil(LiveMessage.decode(Data()))
    }

    func testDemandKindsAreAllRageAndResolvable() {
        XCTAssertFalse(LiveMatchController.demandKinds.isEmpty)
        for kind in LiveMatchController.demandKinds {
            XCTAssertTrue(kind.isRage, "\(kind) is not smackable — bad demand")
            XCTAssertEqual(TargetKind(rawValue: kind.rawValue), kind)
        }
    }
}
