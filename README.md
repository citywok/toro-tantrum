# NO NO NO! — The Rage Game

A whack-a-mole rage-tapper for iPhone, dedicated to the angriest, baldest,
definitely-not-red-headed man in Hawaii. He said "no no no," but he was
smiling, so we shipped it.

## The game

Targets pop up on a Hawaiian sunset board. **Smack the things he hates**
(red hair 🦰, sunscreen 🧴, DNA tests 🧬, tourist cameras 📸, pineapple
pizza 🍕, snowflakes ❄️). **Do NOT touch the things he loves** (the Switch 🎮,
the mai tai 🍹, the hibiscus 🌺, the rainbow 🌈) — that costs a life and
50 points.

- Combo chain: consecutive smacks build a multiplier (up to 4x).
- Rage meter: fill it and he goes **FULL RALPH MODE** — 6 seconds of doubled
  points, faster spawns, and free misses.
- Escaped rage targets cost a life. Three strikes (🌺🌺🌺) and it's
  "GAME OVER, GODDAMNIT."
- Settings → **Ginger Mode**: displays his hair color accurately.

## Layout

- `NoNoNo/Models` — `GameEngine` (deterministic, seeded RNG, fully unit
  tested), `TargetKind`, `QuoteBank`, `ScoreStore`.
- `NoNoNo/Views` — SwiftUI. `FaceView` draws him from flat shapes,
  construction-paper style.
- `NoNoNoTests` / `NoNoNoUITests` — engine/scoring/quote tests + launch flow
  UI tests (run serially on the simulator; see `build.sh`).

## Building

Everything runs on the mac-builder daemon via SQS:

```bash
./trigger-build.sh test        # run XCTests on the simulator
./trigger-build.sh ship        # test → archive → OTA install link
./trigger-build.sh testflight  # upload to TestFlight (needs ASC app record)
```

The Xcode project is generated with `xcodegen` from `project.yml`; there is
no checked-in `.xcodeproj`. Branch must be `mainline` for publish actions.
