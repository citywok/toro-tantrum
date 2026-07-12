import Foundation

/// Everything he yells. Lovingly transcribed from the group chat.
enum QuoteBank {
    static let genericSmack = [
        "NO NO NO!",
        "GODDAMNIT! 😁",
        "ABSOLUTELY NOT!",
        "NOPE. NOPE. NOPE.",
        "GRAAAAH!",
        "NOT TODAY!",
    ]

    static let kindQuotes: [TargetKind: [String]] = [
        .redHair: [
            "I'M NOT A REDHEAD!",
            "THE BEARD DOESN'T COUNT!",
            "IT'S 'AUBURN'— IT'S NOTHING!",
            "DAYWALKER?! HOW DARE YOU.",
        ],
        .sunscreen: [
            "SPF 100 IS NOT A PERSONALITY!",
            "I TAN. SOMETIMES.",
        ],
        .dnaTest: [
            "23-AND-NO!",
            "DELETE MY RESULTS!",
        ],
        .touristCam: [
            "GET OFF MY ISLAND!",
            "THE BEACH IS FULL!",
        ],
        .pineapplePizza: [
            "WHO PUT THIS HERE?!",
            "CRIMES. ACTUAL CRIMES.",
        ],
        .snowflake: [
            "THAT'S WHY I MOVED!",
            "NOT EVEN ONCE.",
        ],
        .switchGame: ["NOT THE SWITCH! GODDAMNIT!"],
        .maiTai: ["MY MAI TAI!! WHY!"],
        .hibiscus: ["THAT WAS DECORATIVE!"],
        .rainbow: ["HOW DARE YOU. THAT ONE'S SACRED."],
    ]

    static let rageModeStart = [
        "FULL RALPH MODE!!",
        "I'M GONNA WRECK IT!!",
        "MAXIMUM GODDAMNIT!!",
    ]

    static let gameOverInsults = [
        "Calm down. It's just a game. (Worse now, huh?)",
        "The DNA test says redhead. The DNA test doesn't lie.",
        "You rage like a tourist.",
        "Breathe in. Aloha. Breathe out. ...GODDAMNIT.",
        "Hawaii called. It would like quieter residents.",
        "Your scalp is sunburned and so is your pride.",
    ]

    static func smackQuote(for kind: TargetKind) -> String {
        let specific = kindQuotes[kind] ?? []
        // Aloha mistakes always get their specific line; rage smacks mix it up.
        if !specific.isEmpty && (!kind.isRage || Bool.random()) {
            return specific.randomElement()!
        }
        return genericSmack.randomElement()!
    }
}
