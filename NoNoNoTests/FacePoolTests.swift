import XCTest
import UIKit
@testable import NoNoNo

final class FacePoolTests: XCTestCase {

    func testEveryMoodHasFaces() {
        for mood in [FaceView.Mood.grinning, .raging, .defeated] {
            XCTAssertFalse(FacePool.pool(for: mood).isEmpty, "\(mood) pool is empty")
        }
    }

    func testRandomFaceComesFromTheMoodPool() {
        for mood in [FaceView.Mood.grinning, .raging, .defeated] {
            for _ in 0..<10 {
                XCTAssertTrue(FacePool.pool(for: mood).contains(FacePool.random(for: mood)))
            }
        }
    }

    func testAllFaceAssetsExist() {
        let allFaces = FacePool.grinning + FacePool.raging + FacePool.defeated
        for name in allFaces {
            XCTAssertNotNil(UIImage(named: name, in: Bundle(for: GameEngine.self), with: nil),
                            "asset catalog is missing \(name)")
        }
    }
}
