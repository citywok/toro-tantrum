import XCTest
@testable import NoNoNo

final class ScoreStoreTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testRecordSetsHighScoreOnlyWhenBeaten() {
        let store = ScoreStore(defaults: makeDefaults())
        XCTAssertEqual(store.highScore, 0)

        XCTAssertTrue(store.record(score: 100, smacks: 10))
        XCTAssertEqual(store.highScore, 100)

        XCTAssertFalse(store.record(score: 50, smacks: 5))
        XCTAssertEqual(store.highScore, 100)

        XCTAssertTrue(store.record(score: 120, smacks: 12))
        XCTAssertEqual(store.highScore, 120)
    }

    func testCountsGamesAndSmacks() {
        let store = ScoreStore(defaults: makeDefaults())
        store.record(score: 10, smacks: 3)
        store.record(score: 20, smacks: 7)
        XCTAssertEqual(store.gamesPlayed, 2)
        XCTAssertEqual(store.totalSmacks, 10)
    }

    func testPersistsAcrossInstances() {
        let defaults = makeDefaults()
        ScoreStore(defaults: defaults).record(score: 250, smacks: 25)

        let reloaded = ScoreStore(defaults: defaults)
        XCTAssertEqual(reloaded.highScore, 250)
        XCTAssertEqual(reloaded.gamesPlayed, 1)
        XCTAssertEqual(reloaded.totalSmacks, 25)
    }
}
