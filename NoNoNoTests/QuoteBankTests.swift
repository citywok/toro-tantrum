import XCTest
@testable import NoNoNo

final class QuoteBankTests: XCTestCase {

    func testEveryTargetKindHasQuotes() {
        for kind in TargetKind.allCases {
            let quotes = QuoteBank.kindQuotes[kind]
            XCTAssertNotNil(quotes, "\(kind) has no quote pool")
            XCTAssertFalse(quotes?.isEmpty ?? true, "\(kind) quote pool is empty")
        }
    }

    func testSmackQuoteComesFromKnownPools() {
        for kind in TargetKind.allCases {
            for _ in 0..<20 {
                let quote = QuoteBank.smackQuote(for: kind)
                let valid = QuoteBank.genericSmack.contains(quote)
                    || (QuoteBank.kindQuotes[kind]?.contains(quote) ?? false)
                XCTAssertTrue(valid, "unexpected quote '\(quote)' for \(kind)")
            }
        }
    }

    func testAlohaMistakesAlwaysGetTheirSpecificLine() {
        for kind in TargetKind.alohaKinds {
            for _ in 0..<10 {
                let quote = QuoteBank.smackQuote(for: kind)
                XCTAssertTrue(QuoteBank.kindQuotes[kind]?.contains(quote) ?? false)
            }
        }
    }

    func testMistakeLineIsTheCatchphrase() {
        XCTAssertEqual(QuoteBank.mistake, "NO NO NO NO NO!")
    }

    func testStaticPoolsAreNonEmpty() {
        XCTAssertFalse(QuoteBank.genericSmack.isEmpty)
        XCTAssertFalse(QuoteBank.rageModeStart.isEmpty)
        XCTAssertFalse(QuoteBank.gameOverInsults.isEmpty)
    }
}
