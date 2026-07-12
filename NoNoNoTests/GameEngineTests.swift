import XCTest
@testable import NoNoNo

final class GameEngineTests: XCTestCase {

    private func makeEngine(alohaChance: Double = 0,
                            seed: UInt64 = 42,
                            tweak: ((inout Tuning) -> Void)? = nil) -> GameEngine {
        var tuning = Tuning()
        tuning.alohaChance = alohaChance
        tweak?(&tuning)
        return GameEngine(tuning: tuning, seed: seed)
    }

    /// Advance the clock in small steps until a target is on the board.
    private func waitForTarget(_ engine: GameEngine,
                               from time: inout TimeInterval) -> SpawnedTarget {
        var steps = 0
        while engine.targets.isEmpty && steps < 1000 {
            time += 0.05
            engine.advance(to: time)
            steps += 1
        }
        precondition(!engine.targets.isEmpty, "no target spawned in 50s of game time")
        return engine.targets[0]
    }

    func testStartInitialState() {
        let engine = makeEngine()
        engine.start(at: 0)
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.lives, Tuning().startLives)
        XCTAssertEqual(engine.level, 1)
        XCTAssertEqual(engine.rage, 0)
        XCTAssertTrue(engine.targets.isEmpty)
    }

    func testTargetSpawnsShortlyAfterStart() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0
        _ = waitForTarget(engine, from: &time)
        XCTAssertFalse(engine.targets.isEmpty)
        XCTAssertLessThan(time, 2.0)
    }

    func testSmackRageTargetScoresAndBuildsRage() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0
        let target = waitForTarget(engine, from: &time)
        XCTAssertTrue(target.kind.isRage)

        let result = engine.smack(target.id, at: time)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lostLife, false)
        XCTAssertEqual(engine.score, target.kind.points)
        XCTAssertEqual(engine.combo, 1)
        XCTAssertEqual(engine.bestCombo, 1)
        XCTAssertGreaterThan(engine.rage, 0)
        XCTAssertEqual(engine.lives, Tuning().startLives)
        XCTAssertFalse(engine.targets.contains(target))
    }

    func testSmackAlohaTargetCostsLifePointsAndCombo() {
        let engine = makeEngine(alohaChance: 1)
        engine.start(at: 0)
        var time: TimeInterval = 0
        let target = waitForTarget(engine, from: &time)
        XCTAssertFalse(target.kind.isRage)

        let result = engine.smack(target.id, at: time)

        XCTAssertEqual(result?.lostLife, true)
        XCTAssertEqual(engine.lives, Tuning().startLives - 1)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.score, 0, "score is floored at zero")
    }

    func testEscapedRageTargetCostsLifeAndResetsCombo() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0
        let target = waitForTarget(engine, from: &time)

        engine.advance(to: target.expiresAt + 0.01)

        XCTAssertEqual(engine.lives, Tuning().startLives - 1)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertFalse(engine.targets.contains(target))
    }

    func testSmackUnknownTargetIsIgnored() {
        let engine = makeEngine()
        engine.start(at: 0)
        XCTAssertNil(engine.smack(UUID(), at: 1))
        XCTAssertEqual(engine.score, 0)
    }

    func testRageModeTriggersDoublesPointsAndEnds() {
        let engine = makeEngine { $0.ragePerSmack = 1.0 }
        engine.start(at: 0)
        var time: TimeInterval = 0

        let first = waitForTarget(engine, from: &time)
        let firstResult = engine.smack(first.id, at: time)
        XCTAssertEqual(firstResult?.enteredRageMode, true)
        XCTAssertTrue(engine.isRageMode)

        // Points double while raging.
        let second = waitForTarget(engine, from: &time)
        let scoreBefore = engine.score
        _ = engine.smack(second.id, at: time)
        XCTAssertEqual(engine.score - scoreBefore, second.kind.points * engine.comboMultiplier * 2)

        // Escapes are free during the frenzy.
        let livesBefore = engine.lives
        let third = waitForTarget(engine, from: &time)
        engine.advance(to: third.expiresAt + 0.01)
        XCTAssertEqual(engine.lives, livesBefore)

        // Rage mode expires and the meter empties.
        engine.advance(to: time + Tuning().rageDuration + 60)
        XCTAssertFalse(engine.isRageMode)
        XCTAssertEqual(engine.rage, 0)
    }

    func testGameOverWhenLivesExhausted() {
        let engine = makeEngine(alohaChance: 1)
        engine.start(at: 0)
        var time: TimeInterval = 0
        for _ in 0..<Tuning().startLives {
            let target = waitForTarget(engine, from: &time)
            _ = engine.smack(target.id, at: time)
        }
        XCTAssertEqual(engine.phase, .gameOver)
        XCTAssertEqual(engine.lives, 0)
        XCTAssertTrue(engine.targets.isEmpty)
    }

    func testLevelUpIncreasesSpeed() {
        let engine = makeEngine { $0.smacksPerLevel = 2 }
        engine.start(at: 0)
        var time: TimeInterval = 0
        let initialInterval = engine.spawnInterval
        let initialLifetime = engine.targetLifetime

        for _ in 0..<2 {
            let target = waitForTarget(engine, from: &time)
            _ = engine.smack(target.id, at: time)
        }

        XCTAssertEqual(engine.level, 2)
        XCTAssertLessThan(engine.spawnInterval, initialInterval)
        XCTAssertLessThan(engine.targetLifetime, initialLifetime)
    }

    func testComboMultiplierGrowsAndCaps() {
        let engine = makeEngine { tuning in
            tuning.ragePerSmack = 0     // never enter rage mode
            tuning.baseLifetime = 120   // nothing escapes
            tuning.minLifetime = 120
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        XCTAssertEqual(engine.comboMultiplier, 1)
        for _ in 0..<20 {
            let target = waitForTarget(engine, from: &time)
            _ = engine.smack(target.id, at: time)
        }
        XCTAssertEqual(engine.combo, 20)
        XCTAssertEqual(engine.bestCombo, 20)
        XCTAssertEqual(engine.comboMultiplier, 4, "multiplier caps at 4x")
    }

    func testResetReturnsToMenu() {
        let engine = makeEngine()
        engine.start(at: 0)
        engine.reset()
        XCTAssertEqual(engine.phase, .ready)
        XCTAssertTrue(engine.targets.isEmpty)
    }

    func testDeterministicWithSameSeed() {
        let a = makeEngine(alohaChance: 0.5, seed: 7)
        let b = makeEngine(alohaChance: 0.5, seed: 7)
        a.start(at: 0)
        b.start(at: 0)
        for step in 1...100 {
            let t = Double(step) * 0.1
            a.advance(to: t)
            b.advance(to: t)
        }
        XCTAssertEqual(a.targets.map(\.kind), b.targets.map(\.kind))
        XCTAssertEqual(a.targets.map(\.x), b.targets.map(\.x))
        XCTAssertEqual(a.lives, b.lives)
    }
}
