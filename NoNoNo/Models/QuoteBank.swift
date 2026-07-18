import Foundation

/// Everything he yells. Lovingly transcribed from the group chat.
enum QuoteBank {
    static let genericSmack = [
        "nooooooooo",
        "nooooooo!",
        "absolutely not",
        "not today!",
        "nope. nope. nope.",
        "graaah!",
    ]

    static let kindQuotes: [TargetKind: [String]] = [
        .onion: [
            "ONIONS?! IN MY FOOD?!",
            "HIDDEN ONIONS. WORST ONIONS.",
            "I CAN TASTE THEM. GOD.",
        ],
        .cucumber: [
            "CUCUMBERS ARE WET NOTHING!",
            "WATER WITH ATTITUDE!",
            "CRUNCHY WATER. DISGUSTING.",
        ],
        .tomato: [
            "TOMATOES?! GET THEM OUT!",
            "SLIMY SEEDS. HATE IT.",
            "NOT WITH MY HOT DOG!",
        ],
        .wasabi: [
            "WASABI IS THE DEVIL'S TOOTHPASTE!",
            "BURNING NOTHING!",
            "IT'S NOT SPICY. IT'S PAIN.",
        ],
        .hotDog: ["NOT THE HOT DOG!!", "I WAS EATING THAT!", "THAT'S MY DINNER!"],
        .dinoNuggets: ["NOT THE DINO NUGS!!", "THOSE WERE MINE!", "YOU MONSTER!"],
        .toro: [
            "NOT THE LAP TORO!!",
            "THAT'S SACRED!",
            "HIDDEN IN MY LAP! HOW DID YOU FIND IT?!",
            "TORO IS LOVE. TORO IS LIFE.",
        ],
    ]

    /// How he introduces himself.
    static let intro = "toro tantrum"

    /// The catchphrase, with the correct cadence. Escapes get this, immediately.
    static let mistake = "nooo, no no no no!"

    /// Smacking something he loves.
    static let badTapMistake = "NOOOO!!"

    static let rageModeStart = [
        "toro tantrum!",
        "LAP TORO MODE!!",
        "HOT DOG TIME!!",
        "DINO RAGE!!",
    ]

    static let gameOverInsults = [
        "Your toro is gone. You have nothing.",
        "Should've hidden it in your lap.",
        "Onions 1, You 0.",
        "Wasabi wins again.",
        "The dino nuggets are extinct. So is your run.",
        "You've been out-hot-dogged.",
        "Calm down. It's just a tantrum.",
        "Screw you guys, I'm eating my toro.",
    ]

    /// Multiplayer handoff trash talk. %@ is the previous player's name.
    static let trashTalkTemplates = [
        "%@ CALLS THAT A SCORE? NOOOOOO.",
        "TORO IS NOT IMPRESSED WITH %@.",
        "%@ RAGES LIKE AN ONION.",
        "EVEN THE DINO NUGGETS OUTSCORE %@.",
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
