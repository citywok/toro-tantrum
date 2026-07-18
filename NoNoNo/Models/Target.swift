import Foundation

/// Things that pop up on the board. Rage targets get smacked for points;
/// aloha targets are the things he actually loves — touch them and pay.
enum TargetKind: String, CaseIterable, Equatable {
    // Rage targets — SMACK (things he hates)
    case onion
    case cucumber
    case tomato
    case wasabi
    // Aloha targets — DO NOT SMACK (things he loves)
    case hotDog
    case dinoNuggets
    case toro

    var isRage: Bool {
        switch self {
        case .onion, .cucumber, .tomato, .wasabi:
            return true
        case .hotDog, .dinoNuggets, .toro:
            return false
        }
    }

    static let rageKinds: [TargetKind] = allCases.filter { $0.isRage }
    static let alohaKinds: [TargetKind] = allCases.filter { !$0.isRage }

    var emoji: String {
        switch self {
        case .onion: return "🧅"
        case .cucumber: return "🥒"
        case .tomato: return "🍅"
        case .wasabi: return "🟢"
        case .hotDog: return "🌭"
        case .dinoNuggets: return "🦕"
        case .toro: return "🍣"
        }
    }

    /// Base points for smacking a rage target. Aloha targets score nothing —
    /// the engine applies a penalty instead.
    var points: Int {
        switch self {
        case .onion, .wasabi: return 25
        case .cucumber, .tomato: return 15
        case .hotDog, .dinoNuggets, .toro: return 0
        }
    }

    /// Short caption shown under the emoji.
    var caption: String? {
        switch self {
        case .onion: return "ONIONS"
        case .cucumber: return "CUCUMBERS"
        case .tomato: return "TOMATOES"
        case .wasabi: return "WASABI"
        case .hotDog: return nil
        case .dinoNuggets: return nil
        case .toro: return nil
        }
    }

    var label: String {
        switch self {
        case .onion: return "onions"
        case .cucumber: return "cucumbers"
        case .tomato: return "tomatoes"
        case .wasabi: return "wasabi"
        case .hotDog: return "the hot dog"
        case .dinoNuggets: return "the dino nuggets"
        case .toro: return "the toro"
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
