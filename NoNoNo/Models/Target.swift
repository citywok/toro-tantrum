import Foundation

/// Things that pop up on the board. Rage targets get smacked for points;
/// aloha targets are the things he actually loves — touch them and pay.
enum TargetKind: String, CaseIterable, Equatable {
    // Rage targets — SMACK
    case redHair
    case sunscreen
    case dnaTest
    case touristCam
    case pineapplePizza
    case snowflake
    // From the group chat's verified list of things Josh hates
    case shannon
    case badDrivers
    case dodTravel
    case hoa
    case thatSong
    case kids
    case newDriver
    case cardio
    // Aloha targets — DO NOT SMACK
    case switchGame
    case maiTai
    case hibiscus
    case rainbow
    case cheeseburger

    var isRage: Bool {
        switch self {
        case .redHair, .sunscreen, .dnaTest, .touristCam, .pineapplePizza, .snowflake,
             .shannon, .badDrivers, .dodTravel, .hoa, .thatSong, .kids, .newDriver,
             .cardio:
            return true
        case .switchGame, .maiTai, .hibiscus, .rainbow, .cheeseburger:
            return false
        }
    }

    static let rageKinds: [TargetKind] = allCases.filter { $0.isRage }
    static let alohaKinds: [TargetKind] = allCases.filter { !$0.isRage }

    var emoji: String {
        switch self {
        case .redHair: return "🦰"
        case .sunscreen: return "🧴"
        case .dnaTest: return "🧬"
        case .touristCam: return "📸"
        case .pineapplePizza: return "🍕"
        case .snowflake: return "❄️"
        case .shannon: return "📛"
        case .badDrivers: return "🚗"
        case .dodTravel: return "✈️"
        case .hoa: return "🏘️"
        case .thatSong: return "🎵"
        case .kids: return "👶"
        case .newDriver: return "🔰"
        case .cardio: return "🏃"
        case .switchGame: return "🎮"
        case .maiTai: return "🍹"
        case .hibiscus: return "🌺"
        case .rainbow: return "🌈"
        case .cheeseburger: return "🍔"
        }
    }

    /// Base points for smacking a rage target. Aloha targets score nothing —
    /// the engine applies a penalty instead.
    var points: Int {
        switch self {
        case .redHair, .shannon: return 25
        case .dnaTest, .thatSong: return 20
        case .pineapplePizza, .badDrivers, .dodTravel, .hoa, .kids, .newDriver,
             .cardio: return 15
        case .sunscreen, .touristCam, .snowflake: return 10
        case .switchGame, .maiTai, .hibiscus, .rainbow, .cheeseburger: return 0
        }
    }

    /// Short caption shown under the emoji for the group-chat hate list —
    /// these need words, an emoji alone doesn't land the joke.
    var caption: String? {
        switch self {
        case .redHair: return "A REDHEAD"
        case .shannon: return "SHANNON LEDDY"
        case .badDrivers: return "DRIVERS"
        case .dodTravel: return "DOD TRAVEL"
        case .hoa: return "THE HOA"
        case .thatSong: return "WORKING B!TCH"
        case .kids: return "KIDS"
        case .newDriver: return "STUDENT DRIVER"
        case .cardio: return "CARDIO"
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .redHair: return "red hair"
        case .sunscreen: return "sunscreen"
        case .dnaTest: return "DNA test"
        case .touristCam: return "tourist camera"
        case .pineapplePizza: return "pineapple pizza"
        case .snowflake: return "snowflake"
        case .shannon: return "Shannon"
        case .badDrivers: return "people driving in his vicinity"
        case .dodTravel: return "DoD travel booking"
        case .hoa: return "the HOA"
        case .thatSong: return "Working Bitch by Ashnikko"
        case .kids: return "kids"
        case .newDriver: return "the student driver bumper sticker"
        case .cardio: return "cardio"
        case .switchGame: return "the Switch"
        case .maiTai: return "the mai tai"
        case .hibiscus: return "the hibiscus"
        case .rainbow: return "the rainbow"
        case .cheeseburger: return "the cheeseburger"
        }
    }
}

struct SpawnedTarget: Identifiable, Equatable {
    let id: UUID
    let kind: TargetKind
    /// Position in unit coordinates (0...1) within the game board.
    let x: Double
    let y: Double
    let expiresAt: TimeInterval
}
