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
    // Aloha targets — DO NOT SMACK
    case switchGame
    case maiTai
    case hibiscus
    case rainbow

    var isRage: Bool {
        switch self {
        case .redHair, .sunscreen, .dnaTest, .touristCam, .pineapplePizza, .snowflake:
            return true
        case .switchGame, .maiTai, .hibiscus, .rainbow:
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
        case .switchGame: return "🎮"
        case .maiTai: return "🍹"
        case .hibiscus: return "🌺"
        case .rainbow: return "🌈"
        }
    }

    /// Base points for smacking a rage target. Aloha targets score nothing —
    /// the engine applies a penalty instead.
    var points: Int {
        switch self {
        case .redHair: return 25
        case .dnaTest: return 20
        case .pineapplePizza: return 15
        case .sunscreen, .touristCam, .snowflake: return 10
        case .switchGame, .maiTai, .hibiscus, .rainbow: return 0
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
        case .switchGame: return "the Switch"
        case .maiTai: return "the mai tai"
        case .hibiscus: return "the hibiscus"
        case .rainbow: return "the rainbow"
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
