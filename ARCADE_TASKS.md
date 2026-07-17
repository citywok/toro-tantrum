# Arcade-Feel Improvements — Task List

## Overview
Transform NO NO NO! from a mobile casual game into a punchy arcade experience.
All items address specific arcade-feel gaps identified in the code review.

## Tasks (in implementation order)

### ✅ Task 1: Screen shake on escapes & mistakes
- **File:** `GameView.swift`
- **What:** Add `shakePhase` increment in the `onChange(of: engine.lastLifeLoss)` handler so the board shakes when the player makes a mistake or lets a target escape.
- **Arcade payoff:** Punishment has PHYSICAL feedback, not just visual.
- **Difficulty:** Trivial

### ✅ Task 2: Combo milestone callouts ("NICE!" / "GREAT!" / etc.)
- **File:** `GameView.swift`
- **What:** Watch `engine.combo`. At thresholds 5, 10, 15, 20 → show big centered text. On combo break (drop from ≥5), show "COMBO BROKEN!" in red.
- **Arcade payoff:** Arcade games CELEBRATE your streaks and MOCK your failures.
- **Difficulty:** Easy

### ✅ Task 3: Extra life at score milestones
- **File:** `GameEngine.swift`
- **What:** Every 1000 points → gain +1 life (capped at starting lives). Publish an event so the UI can celebrate.
- **Arcade payoff:** The classic carrot-on-a-stick — keeps players pushing.
- **Difficulty:** Easy

### ✅ Task 4: Rage meter near-full glow/pulse
- **File:** `GameView.swift`
- **What:** When `rage > 0.8` and not already in rage mode, make the meter bar pulse with a yellow glow.
- **Arcade payoff:** Creates urgency and anticipation — "ALMOST THERE!"
- **Difficulty:** Trivial

### ✅ Task 5: Arcade 3-2-1-GO! countdown
- **File:** `GameEngine.swift` + `GameView.swift`
- **What:** Engine delays first spawn by 3 seconds and publishes a countdown. GameView shows huge centered numbers, then "GO!".
- **Arcade payoff:** Builds anticipation before the chaos. Every arcade game does this.
- **Difficulty:** Easy

### ✅ Task 6: Punchier score popups (fly-up animation)
- **File:** `GameView.swift`
- **What:** Replace static positioned score text with a `BurstView` that animates upward while fading out.
- **Arcade payoff:** Score numbers that *move* feel more impactful.
- **Difficulty:** Easy

### ✅ Task 7: Dynamic music intensity
- **File:** `SoundKit.swift`
- **What:** Generate 3 BPM variants of the chiptune (normal 140, intense 160, rage 180). Swap buffers based on game state.
- **Arcade payoff:** Music that speeds up with the action = primal excitement.
- **Difficulty:** Medium

### ✅ Task 8: Game Over "CONTINUE?" countdown
- **File:** `GameOverView.swift`
- **What:** Show a 10-second continue countdown overlay. If player taps, restart; if it expires, show full stats.
- **Arcade payoff:** The arcade "CONTINUE?" screen is iconic — builds tension and urgency.
- **Difficulty:** Easy

### ✅ Task 9: Post-game stat breakdown
- **File:** `GameOverView.swift`, `GameEngine.swift`
- **What:** Track total taps and rage mode activations in engine. Show accuracy %, rage modes triggered, and stat breakdown on game over screen.
- **Arcade payoff:** Stats screen = bragging rights and self-improvement.
- **Difficulty:** Easy
