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

    /// Advance the clock in small steps until a matching target is on the board.
    private func waitForTarget(_ engine: GameEngine,
                               from time: inout TimeInterval,
                               where predicate: (SpawnedTarget) -> Bool = { _ in true }) -> SpawnedTarget {
        var steps = 0
        while steps < 5000 {
            if let match = engine.targets.first(where: predicate) { return match }
            time += 0.05
            engine.advance(to: time)
            steps += 1
        }
        preconditionFailure("no matching target spawned in 250s of game time")
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
        XCTAssertEqual(engine.countdownSeconds, 3)
        XCTAssertEqual(engine.totalTaps, 0)
        XCTAssertEqual(engine.extraLifeCount, 0)
        XCTAssertEqual(engine.rageModeCount, 0)
        XCTAssertTrue(engine.targets.isEmpty)
    }

    func testTargetSpawnsShortlyAfterStart() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0
        _ = waitForTarget(engine, from: &time)
        XCTAssertFalse(engine.targets.isEmpty)
        XCTAssertGreaterThan(time, 3.0, "target spawns after 3s countdown")
        XCTAssertLessThan(time, 4.0)
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

    func testBadTapEmitsLifeLossEvent() {
        let engine = makeEngine(alohaChance: 1)
        engine.start(at: 0)
        var time: TimeInterval = 0
        let target = waitForTarget(engine, from: &time)
        _ = engine.smack(target.id, at: time)
        XCTAssertEqual(engine.lastLifeLoss?.cause, .badTap)
        XCTAssertEqual(engine.lastLifeLoss?.kind, target.kind)
        XCTAssertEqual(engine.lastLifeLoss?.seq, 1)
    }

    func testEscapeEmitsLifeLossEventWithIncrementingSeq() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0
        let first = waitForTarget(engine, from: &time)
        engine.advance(to: first.expiresAt + 0.01)
        XCTAssertEqual(engine.lastLifeLoss?.cause, .escape)
        XCTAssertEqual(engine.lastLifeLoss?.seq, 1)

        time = first.expiresAt + 0.01
        let second = waitForTarget(engine, from: &time)
        engine.advance(to: second.expiresAt + 0.01)
        XCTAssertEqual(engine.lastLifeLoss?.seq, 2)
    }

    func testGreenTargetsStillCostALifeWhileRaging() {
        let engine = makeEngine(alohaChance: 0.5, seed: 7) { tuning in
            tuning.ragePerSmack = 1.0
            tuning.rageDuration = 600
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        // Enter rage mode via a rage-target smack.
        let rageTarget = waitForTarget(engine, from: &time) { $0.kind.isRage }
        _ = engine.smack(rageTarget.id, at: time)
        XCTAssertTrue(engine.isRageMode)

        // Being drunk is not a defense: green taps still cost a life.
        let alohaTarget = waitForTarget(engine, from: &time) { !$0.kind.isRage }
        let livesBefore = engine.lives
        let result = engine.smack(alohaTarget.id, at: time)

        XCTAssertEqual(result?.lostLife, true)
        XCTAssertEqual(engine.lives, livesBefore - 1)
        XCTAssertEqual(engine.lastLifeLoss?.cause, .badTap)
    }

    func testTimedRoundEndsAtDuration() {
        let engine = makeEngine { $0.roundDuration = 10 }
        engine.start(at: 0)
        engine.advance(to: 9)
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertEqual(engine.timeLeft ?? -1, 1, accuracy: 0.001)
        engine.advance(to: 10.01)
        XCTAssertEqual(engine.phase, .gameOver)
        XCTAssertTrue(engine.targets.isEmpty)
    }

    func testEndlessModeHasNoTimer() {
        let engine = makeEngine()
        engine.start(at: 0)
        engine.advance(to: 100)
        XCTAssertNil(engine.timeLeft)
    }

    func testSeededStartReplaysIdenticalRounds() {
        // Different construction seeds, same start seed → identical rounds.
        let a = makeEngine(alohaChance: 0.4, seed: 1)
        let b = makeEngine(alohaChance: 0.4, seed: 2)
        a.start(at: 0, seed: 99)
        b.start(at: 0, seed: 99)
        for step in 1...100 {
            let t = Double(step) * 0.05
            a.advance(to: t)
            b.advance(to: t)
        }
        XCTAssertFalse(a.targets.isEmpty, "board should be live at the comparison point")
        XCTAssertEqual(a.targets.map(\.kind), b.targets.map(\.kind))
        XCTAssertEqual(a.targets.map(\.x), b.targets.map(\.x))
        XCTAssertEqual(a.lives, b.lives)
    }

    func testAwardBonusOnlyWhilePlaying() {
        let engine = makeEngine()
        engine.awardBonus(100)
        XCTAssertEqual(engine.score, 0, "no bonus before the game starts")
        engine.start(at: 0)
        engine.awardBonus(100)
        XCTAssertEqual(engine.score, 100)
    }

    func testDrainRageFloorsAtZero() {
        let engine = makeEngine()
        engine.start(at: 0)
        engine.drainRage()
        XCTAssertEqual(engine.rage, 0)
    }

    func testSpawnDecoysAddsAlohaTargetsWithOverflow() {
        let engine = makeEngine()
        engine.start(at: 0)
        engine.spawnDecoys(2, at: 0.1)
        let decoys = engine.targets.filter { !$0.kind.isRage }
        XCTAssertEqual(decoys.count, 2)
        XCTAssertLessThanOrEqual(engine.targets.count, Tuning().maxTargetsOnScreen + 3)
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

    // MARK: - Arcade improvements

    func testCountdownStartsAtThreeAndBlocksTargets() {
        let engine = makeEngine()
        engine.start(at: 0)
        XCTAssertEqual(engine.countdownSeconds, 3, "countdown starts at 3")
        XCTAssertTrue(engine.targets.isEmpty, "no targets before countdown")

        // Advance partway through countdown — no targets yet.
        engine.advance(to: 1.0)
        XCTAssertEqual(engine.countdownSeconds, 2)
        XCTAssertTrue(engine.targets.isEmpty, "no targets during countdown")

        engine.advance(to: 2.0)
        XCTAssertEqual(engine.countdownSeconds, 1)
        XCTAssertTrue(engine.targets.isEmpty, "no targets during countdown")
    }

    func testTargetsSpawnAfterCountdown() {
        let engine = makeEngine()
        engine.start(at: 0)
        var time: TimeInterval = 0

        // waitForTarget advances past the countdown and finds the first target.
        let target = waitForTarget(engine, from: &time)
        XCTAssertEqual(engine.countdownSeconds, 0, "countdown finished")
        XCTAssertGreaterThan(time, 3.0, "target spawned after 3s countdown")
        XCTAssertFalse(engine.targets.isEmpty)
        // Also verify the target is a valid kind.
        XCTAssertTrue(TargetKind.allCases.contains(target.kind))
    }

    func testTotalTapsIncrementsOnSmack() {
        let engine = makeEngine(alohaChance: 0.5) { tuning in
            tuning.ragePerSmack = 0
            tuning.baseSpawnInterval = 0.1
            tuning.minSpawnInterval = 0.1
            tuning.baseLifetime = 120
            tuning.minLifetime = 120
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        // Smack a rage target.
        let rageTarget = waitForTarget(engine, from: &time) { $0.kind.isRage }
        _ = engine.smack(rageTarget.id, at: time)
        XCTAssertEqual(engine.totalTaps, 1, "good smack counts as tap")

        // Smack an aloha target (need one on the board).
        let aloha = waitForTarget(engine, from: &time) { !$0.kind.isRage }
        _ = engine.smack(aloha.id, at: time)
        XCTAssertEqual(engine.totalTaps, 2, "bad smack also counts as tap")

        // Invalid id — no increment.
        _ = engine.smack(UUID(), at: time)
        XCTAssertEqual(engine.totalTaps, 2, "invalid smack does not count")
    }

    func testExtraLifeCountsAtScoreMilestone() {
        let engine = makeEngine { tuning in
            tuning.ragePerSmack = 0
            tuning.baseSpawnInterval = 0.1
            tuning.minSpawnInterval = 0.1
            tuning.baseLifetime = 600
            tuning.minLifetime = 600
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        // Smack rage targets until score crosses 1000.
        while engine.score < 1000 && engine.phase == .playing {
            let target = waitForTarget(engine, from: &time) { $0.kind.isRage }
            _ = engine.smack(target.id, at: time)
        }

        XCTAssertTrue(engine.score >= 1000)
        XCTAssertEqual(engine.extraLifeCount, 1, "extra life triggered at 1000 pts")
        XCTAssertEqual(engine.lives, Tuning().startLives, "lives capped at startLives")
    }

    func testExtraLifeRestoresLostLife() {
        let engine = makeEngine { tuning in
            tuning.ragePerSmack = 0
            tuning.baseSpawnInterval = 0.1
            tuning.minSpawnInterval = 0.1
            tuning.baseLifetime = 0.2
            tuning.minLifetime = 0.2
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        // Let the first target escape to lose a life.
        let target = waitForTarget(engine, from: &time)
        time = target.expiresAt + 0.01
        engine.advance(to: time)
        XCTAssertEqual(engine.lives, Tuning().startLives - 1, "lost a life to escape")

        // Build score to 1000.
        while engine.score < 1000 && engine.phase == .playing {
            let t = waitForTarget(engine, from: &time) { $0.kind.isRage }
            _ = engine.smack(t.id, at: time)
        }

        XCTAssertTrue(engine.score >= 1000)
        XCTAssertEqual(engine.extraLifeCount, 1, "extra life triggered")
        XCTAssertEqual(engine.lives, Tuning().startLives, "life restored to startLives")
    }

    func testRageModeCountIncrements() {
        let engine = makeEngine { tuning in
            tuning.ragePerSmack = 1.0  // trigger rage on first smack
            tuning.baseSpawnInterval = 0.1
            tuning.minSpawnInterval = 0.1
            tuning.baseLifetime = 600
            tuning.minLifetime = 600
        }
        engine.start(at: 0)
        var time: TimeInterval = 0

        // One smack should trigger rage mode.
        let first = waitForTarget(engine, from: &time) { $0.kind.isRage }
        let result = engine.smack(first.id, at: time)
        XCTAssertTrue(result?.enteredRageMode ?? false)
        XCTAssertEqual(engine.rageModeCount, 1)

        // Smack another target during rage mode (ragePerSmack is 1.0 but already raging).
        let second = waitForTarget(engine, from: &time) { $0.kind.isRage }
        _ = engine.smack(second.id, at: time)
        XCTAssertEqual(engine.rageModeCount, 1, "rage mode count does not double-count")

        // Let rage expire and trigger it again.
        time += Tuning().rageDuration + 60
        engine.advance(to: time)
        XCTAssertFalse(engine.isRageMode)

        // Wait for a fresh target and smack to re-enter rage.
        let third = waitForTarget(engine, from: &time) { $0.kind.isRage }
        _ = engine.smack(third.id, at: time)
        XCTAssertTrue(engine.isRageMode)
        XCTAssertEqual(engine.rageModeCount, 2, "rage mode count incremented again")
    }
}
