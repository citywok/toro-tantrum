import Foundation

/// Wire protocol for MULTIPLAYER. JSON over MultipeerConnectivity.
/// Non-host messages travel to the host, which relays them to everyone else.
enum LiveMessage: Codable, Equatable {
    /// Joiner → host on connect.
    case hello(name: String)
    /// Host → all: ordered player list, host first.
    case roster(names: [String])
    /// Host → all: same seed everywhere, start after `delay` seconds.
    case start(seed: UInt64, delay: TimeInterval)
    /// Any → all (via host): live score update.
    case score(name: String, score: Int)
    /// Any → all: this player just went JOSH SMASHED — sabotage the rest.
    case smashed(name: String)
    /// Host → all: JOSH DEMANDS that `player` smack `kind` within `window` seconds.
    case demand(id: UUID, kindRaw: String, player: String, window: TimeInterval)
    /// Named player → all: how the demand ended.
    case demandResult(id: UUID, player: String, fulfilled: Bool)
    /// Any → all: round finished with this final score.
    case finalScore(name: String, score: Int)

    static func decode(_ data: Data) -> LiveMessage? {
        try? JSONDecoder().decode(LiveMessage.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
