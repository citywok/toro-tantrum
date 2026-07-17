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
        .shannon: [
            "NOT TODAY, SHANNON.",
            "SHE KNOWS WHAT SHE DID.",
        ],
        .badDrivers: [
            "USE YOUR BLINKER!!",
            "WHO TAUGHT YOU TO DRIVE?!",
        ],
        .dodTravel: [
            "A 6 A.M. CONNECTION?! THROUGH ATLANTA?!",
            "MIDDLE SEAT. AGAIN. GODDAMNIT.",
        ],
        .hoa: [
            "IT'S MY LAWN!!",
            "FINED?! FOR WHAT?!",
        ],
        .thatSong: [
            "SKIP IT. SKIP IT NOW.",
            "ASHNIKKO KNOWS WHAT SHE DID.",
            "NOT THAT SONG. NO.",
        ],
        .kids: [
            "NOT AT BRUNCH!!",
            "WHOSE CHILD IS THIS?!",
        ],
        .newDriver: [
            "A LEARNER?! ON MY ROAD?!",
            "THE STICKER ISN'T A SHIELD!",
        ],
        .cardio: [
            "MY KNEES ARE DECORATIVE!!",
            "I SPRINT ONLY TO BRUNCH.",
        ],
        .switchGame: ["NOT THE SWITCH! GODDAMNIT!"],
        .maiTai: ["MY MAI TAI!! WHY!"],
        .hibiscus: ["THAT WAS DECORATIVE!"],
        .rainbow: ["HOW DARE YOU. THAT ONE'S SACRED."],
        .cheeseburger: ["NOT THE BURGER!! GODDAMNIT!", "I WAS EATING THAT!"],
        .tankTop: ["NOT THE TANK TOP!!", "IT'S SLEEVELESS SEASON, GODDAMNIT!"],
        .dragQueen: [
            "NOT THE DRAG QUEEN!!",
            "THAT'S ART, GODDAMNIT!",
            "THE NAILS! THE BEAT! RESPECT IT!",
        ],
    ]

    /// How he introduces himself. Formally. In French.
    static let intro = "josh smash"

    /// The catchphrase, with the correct cadence. Escapes get this, immediately.
    static let mistake = "NO, NO NO NO NO!"

    /// Smacking something he loves.
    static let badTapMistake = "GODDAMNIT!! 😁"

    static let rageModeStart = [
        "josh smash",
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
        "josh smashed!",
        "Oh my god, you killed the combo. You bastard!",
        "Screw you guys. He's going home.",
    ]

    /// Rage-Off handoff trash talk. %@ is the previous player's name.
    static let trashTalkTemplates = [
        "%@ CALLS THAT A SCORE? GODDAMNIT.",
        "JOSH IS NOT IMPRESSED WITH %@.",
        "%@ RAGES LIKE A TOURIST.",
        "EVEN THE GINGERS OUTSCORE %@.",
        "%@... NO. JUST NO. NO NO NO.",
    ]

    static func trashTalk(for name: String) -> String {
        String(format: trashTalkTemplates.randomElement() ?? "%@.", name)
    }

    static func smackQuote(for kind: TargetKind) -> String {
        let specific = kindQuotes[kind] ?? []
        // Aloha mistakes always get their specific line; rage smacks mix it up.
        if !specific.isEmpty && (!kind.isRage || Bool.random()) {
            return specific.randomElement()!
        }
        return genericSmack.randomElement()!
    }
}
