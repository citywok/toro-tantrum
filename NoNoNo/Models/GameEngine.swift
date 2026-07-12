import Foundation

enum GamePhase: Equatable {
    case ready
    case playing
    case gameOver
}

/// Knobs for pacing and difficulty. All values have defaults so tests can
/// tweak a single field via the memberwise initializer.
struct Tuning {
    var startLives = 3
    var baseSpawnInterval: TimeInterval = 0.95
    var minSpawnInterval: TimeInterval = 0.38
    var baseLifetime: TimeInterval = 1.7
    var minLifetime: TimeInterval = 0.85
    /// Chance a spawn is an aloha (do-not-smack) target.
    var alohaChance: Double = 0.2
    var ragePerSmack: Double = 0.13
    var rageDuration: TimeInterval = 6
    var smacksPerLevel = 10
    var maxTargetsOnScreen = 4
}

/// Deterministic RNG so tests can replay exact games.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func int(below n: Int) -> Int {
        Int(next() % UInt64(n))
    }
}

final class GameEngine: ObservableObject {
    struct SmackResult: Equatable {
        let kind: TargetKind
        let pointsAwarded: Int
        let lostLife: Bool
        let enteredRageMode: Bool
    }

    @Published private(set) var phase: GamePhase = .ready
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var lives = 3
    @Published private(set) var level = 1
    /// 0...1; at 1 the game enters rage mode.
    @Published private(set) var rage: Double = 0
    @Published private(set) var isRageMode = false
    @Published private(set) var targets: [SpawnedTarget] = []
    @Published private(set) var smacks = 0

    let tuning: Tuning
    private var rng: SplitMix64
    private var nextSpawnAt: TimeInterval = 0
    private var rageEndsAt: TimeInterval = 0

    init(tuning: Tuning = Tuning(), seed: UInt64? = nil) {
        self.tuning = tuning
        self.rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.lives = tuning.startLives
    }

    /// Combo builds a multiplier: every 5 consecutive smacks adds 1x, capped at 4x.
    var comboMultiplier: Int { min(1 + combo / 5, 4) }

    var spawnInterval: TimeInterval {
        let base = max(tuning.minSpawnInterval,
                       tuning.baseSpawnInterval - Double(level - 1) * 0.07)
        return isRageMode ? base * 0.55 : base
    }

    var targetLifetime: TimeInterval {
        max(tuning.minLifetime, tuning.baseLifetime - Double(level - 1) * 0.09)
    }

    func start(at now: TimeInterval) {
        score = 0
        combo = 0
        bestCombo = 0
        lives = tuning.startLives
        level = 1
        rage = 0
        isRageMode = false
        targets = []
        smacks = 0
        nextSpawnAt = now + 0.4
        phase = .playing
    }

    func reset() {
        phase = .ready
        targets = []
    }

    /// Drive the game clock forward. Call from a display-rate timer.
    func advance(to now: TimeInterval) {
        guard phase == .playing else { return }

        if isRageMode && now >= rageEndsAt {
            isRageMode = false
            rage = 0
        }

        let escaped = targets.filter { $0.expiresAt <= now }
        if !escaped.isEmpty {
            targets.removeAll { $0.expiresAt <= now }
            for target in escaped where target.kind.isRage {
                combo = 0
                // Rage mode is a frenzy: escapes are free.
                if !isRageMode {
                    loseLife()
                }
            }
        }

        while phase == .playing && now >= nextSpawnAt {
            if targets.count < tuning.maxTargetsOnScreen {
                targets.append(makeTarget(at: now))
            }
            nextSpawnAt += spawnInterval
        }
    }

    @discardableResult
    func smack(_ id: UUID, at now: TimeInterval) -> SmackResult? {
        guard phase == .playing,
              let index = targets.firstIndex(where: { $0.id == id }) else { return nil }
        let target = targets.remove(at: index)

        guard target.kind.isRage else {
            combo = 0
            score = max(0, score - 50)
            rage = max(0, rage - 0.25)
            loseLife()
            return SmackResult(kind: target.kind, pointsAwarded: -50,
                               lostLife: true, enteredRageMode: false)
        }

        smacks += 1
        combo += 1
        bestCombo = max(bestCombo, combo)
        if smacks % tuning.smacksPerLevel == 0 { level += 1 }

        var points = target.kind.points * comboMultiplier
        if isRageMode { points *= 2 }
        score += points

        var enteredRage = false
        if !isRageMode {
            rage = min(1, rage + tuning.ragePerSmack)
            if rage >= 1 {
                isRageMode = true
                rageEndsAt = now + tuning.rageDuration
                enteredRage = true
            }
        }

        return SmackResult(kind: target.kind, pointsAwarded: points,
                           lostLife: false, enteredRageMode: enteredRage)
    }

    private func loseLife() {
        lives -= 1
        if lives <= 0 {
            lives = 0
            phase = .gameOver
            targets = []
        }
    }

    private func makeTarget(at now: TimeInterval) -> SpawnedTarget {
        let alohaChance = isRageMode ? 0.05 : tuning.alohaChance
        let pool = rng.unit() < alohaChance ? TargetKind.alohaKinds : TargetKind.rageKinds
        let kind = pool[rng.int(below: pool.count)]
        return SpawnedTarget(id: UUID(),
                             kind: kind,
                             x: 0.10 + rng.unit() * 0.80,
                             y: 0.08 + rng.unit() * 0.82,
                             expiresAt: now + targetLifetime)
    }
}
