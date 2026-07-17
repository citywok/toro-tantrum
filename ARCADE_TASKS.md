# Arcade-Feel Improvements — Task List

## Overview
Transform NO NO NO! from a mobile casual game into a punchy arcade experience.
All items address specific arcade-feel gaps identified in the code review.

## Tasks (in implementation order)

### ✅ Task 1: Screen shake on escapes & mistakes
- **File:** `GameView.swift`
- **What:** Added `shakePhase += 3` in the `onChange(of: engine.lastLifeLoss)` handler so the board shakes when the player makes a mistake or lets a target escape.
- **Arcade payoff:** Punishment has PHYSICAL feedback, not just visual.

### ✅ Task 2: Combo milestone callouts ("NICE!" / "GREAT!" / etc.)
- **File:** `GameView.swift`
- **What:** Watches `engine.combo`. At thresholds 5, 10, 15, 20 → shows big centered text. On combo break (drop from ≥5), shows "COMBO BROKEN!" in red.
- **Arcade payoff:** Arcade games CELEBRATE your streaks and MOCK your failures.

### ✅ Task 3: Extra life at score milestones
- **File:** `GameEngine.swift`
- **What:** Every 1000 points → gain +1 life (capped at starting lives). Publishes `extraLifeCount` so the UI celebrates.
- **Arcade payoff:** The classic carrot-on-a-stick — keeps players pushing.

### ✅ Task 4: Rage meter near-full glow/pulse
- **File:** `GameView.swift`
- **What:** When `rage > 0.8` and not already in rage mode, the meter bar pulses with a yellow stroke overlay.
- **Arcade payoff:** Creates urgency and anticipation — "ALMOST THERE!"

### ✅ Task 5: Arcade 3-2-1-GO! countdown
- **File:** `GameEngine.swift` + `GameView.swift`
- **What:** Engine publishes `countdownSeconds` (3, 2, 1, 0) on game start. First spawn is delayed by 3 seconds. GameView shows huge centered numbers, then "GO!".
- **Arcade payoff:** Builds anticipation before the chaos.

### ✅ Task 6: Punchier score popups (fly-up animation)
- **File:** `GameView.swift`
- **What:** New `BurstView` struct replaces static positioned score text. Animate upward by 44 points while fading out over 0.5s.
- **Arcade payoff:** Score numbers that *move* feel more impactful.

### ✅ Task 7: Dynamic music intensity
- **File:** `SoundKit.swift`
- **What:** New `MusicIntensity` enum (normal 140 BPM, intense 165 BPM, rage 190 BPM). `setMusicIntensity()` swaps the looping buffer based on combo/rage state. Buffers cached lazily.
- **Arcade payoff:** Music that speeds up with the action = primal excitement.

### ✅ Task 8: Game Over "CONTINUE?" countdown
- **File:** `GameOverView.swift`
- **What:** 10-second continue countdown overlay appears on game over. Player can tap to restart or wait for it to expire → full stats screen.
- **Arcade payoff:** The arcade "CONTINUE?" screen is iconic — builds tension and urgency.

### ✅ Task 9: Post-game stat breakdown
- **File:** `GameEngine.swift`, `GameOverView.swift`, `RootView.swift`
- **What:** Engine tracks `totalTaps` and `rageModeCount`. GameOverView shows accuracy %, rage modes triggered, and a 4-column stat row.
- **Arcade payoff:** Stats screen = bragging rights and self-improvement.
