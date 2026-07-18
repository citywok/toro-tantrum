# TORO TANTRUM! — The Nug Rage

A whack-a-mole rage-tapper re-skinned to make fun of a friend who loves hot
dogs and dino nuggets but absolutely hates onions, cucumbers, tomatoes, and
wasabi. He also loves toro (fatty tuna). One time he hid his last piece of
toro in his lap at dinner. We called it lap toro for years.

## The game

Targets pop up on a prehistoric jungle board. **Smack the things he hates**
(onions 🧅, cucumbers 🥒, tomatoes 🍅, wasabi 🟢).
**Do NOT touch the things he loves** (the hot dog 🌭, the dino nuggets 🦕,
the toro 🍣) — that costs a life and 50 points.

- Combo chain: consecutive smacks build a multiplier (up to 4x).
- Rage meter: fill it and he goes **LAP TORO MODE** — 6 seconds of doubled
  points, faster spawns, and free misses.
- Escaped rage targets cost a life. Three strikes (🥚🥚🥚) and it's
  "GAME OVER, NOOOOOO."
- Settings → **Wasabi Mode**: displays his hatred of wasabi accurately.

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
