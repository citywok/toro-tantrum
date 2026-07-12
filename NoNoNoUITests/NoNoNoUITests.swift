import XCTest

final class NoNoNoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // On iOS 26 simulators SwiftUI controls may not appear under app.buttons,
    // so query descendants(matching: .any) by identifier.
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testMenuToGameFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let start = element(app, "startButton")
        XCTAssertTrue(start.waitForExistence(timeout: 10), "start button missing")
        start.tap()

        XCTAssertTrue(element(app, "gameBoard").waitForExistence(timeout: 5),
                      "game board did not appear after start")
        XCTAssertTrue(element(app, "scoreLabel").waitForExistence(timeout: 5),
                      "score HUD missing")
        XCTAssertTrue(element(app, "quoteLabel").waitForExistence(timeout: 5),
                      "speech bubble missing")
    }

    func testRageOffReachesHandoff() throws {
        let app = XCUIApplication()
        app.launch()

        let rageOff = element(app, "rageOffButton")
        XCTAssertTrue(rageOff.waitForExistence(timeout: 10), "rage-off button missing")
        rageOff.tap()

        let startMatch = element(app, "startMatchButton")
        XCTAssertTrue(startMatch.waitForExistence(timeout: 5), "rage-off setup missing")
        startMatch.tap()

        XCTAssertTrue(element(app, "readyButton").waitForExistence(timeout: 5),
                      "handoff screen missing")
    }

    func testSettingsOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        let gear = element(app, "settingsButton")
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "settings button missing")
        gear.tap()

        XCTAssertTrue(element(app, "gingerToggle").waitForExistence(timeout: 5),
                      "Ginger Mode toggle missing")
        XCTAssertTrue(element(app, "soundToggle").waitForExistence(timeout: 5),
                      "Game sounds toggle missing")
        XCTAssertTrue(element(app, "cartoonToggle").waitForExistence(timeout: 5),
                      "Cartoon Mode toggle missing")

        let done = element(app, "settingsDoneButton")
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(element(app, "startButton").waitForExistence(timeout: 5),
                      "did not return to menu after closing settings")
    }
}
