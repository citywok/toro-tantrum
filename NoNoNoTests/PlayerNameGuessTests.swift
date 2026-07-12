import XCTest
@testable import NoNoNo

final class PlayerNameGuessTests: XCTestCase {

    func testParsesPossessiveDeviceNames() {
        XCTAssertEqual(PlayerNameGuess.firstName(fromDeviceName: "Josh's iPhone"), "Josh")
        XCTAssertEqual(PlayerNameGuess.firstName(fromDeviceName: "Josh\u{2019}s iPhone"), "Josh",
                       "curly apostrophe is what iOS actually uses")
        XCTAssertEqual(PlayerNameGuess.firstName(fromDeviceName: "Mary Jo's iPad"), "Mary Jo")
    }

    func testGenericDeviceNamesReturnNil() {
        XCTAssertNil(PlayerNameGuess.firstName(fromDeviceName: "iPhone"))
        XCTAssertNil(PlayerNameGuess.firstName(fromDeviceName: "iPad"))
        XCTAssertNil(PlayerNameGuess.firstName(fromDeviceName: "iPhone 15 Pro"))
        XCTAssertNil(PlayerNameGuess.firstName(fromDeviceName: ""))
    }

    func testCustomDeviceNamePassesThrough() {
        XCTAssertEqual(PlayerNameGuess.firstName(fromDeviceName: "Mothership"), "Mothership")
    }
}
