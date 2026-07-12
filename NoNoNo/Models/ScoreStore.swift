import Foundation

final class ScoreStore: ObservableObject {
    @Published private(set) var highScore: Int
    @Published private(set) var gamesPlayed: Int
    @Published private(set) var totalSmacks: Int

    private enum Key {
        static let highScore = "highScore"
        static let gamesPlayed = "gamesPlayed"
        static let totalSmacks = "totalSmacks"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.highScore = defaults.integer(forKey: Key.highScore)
        self.gamesPlayed = defaults.integer(forKey: Key.gamesPlayed)
        self.totalSmacks = defaults.integer(forKey: Key.totalSmacks)
    }

    /// Records a finished game. Returns true if this set a new high score.
    @discardableResult
    func record(score: Int, smacks: Int) -> Bool {
        gamesPlayed += 1
        totalSmacks += smacks
        defaults.set(gamesPlayed, forKey: Key.gamesPlayed)
        defaults.set(totalSmacks, forKey: Key.totalSmacks)
        guard score > highScore else { return false }
        highScore = score
        defaults.set(highScore, forKey: Key.highScore)
        return true
    }
}
