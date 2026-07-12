# NO NO NO! — Development, Build & Deploy Guide

Gag-gift rage-tapper for Josh. SwiftUI, iOS 16+, bundle `me.citywok.nonono`,
App Store Connect app record **"Josh Smash"** (id 6790039068). Repo:
`github.com/citywok/nonono-ios`, default branch **mainline** (the mac-builder
daemon refuses publish actions from any other branch name).

## How development works

There is no checked-in `.xcodeproj` — the project is generated from
`project.yml` by **xcodegen** on the build Mac. Just edit Swift files and
push; the pipeline does the rest.

### Where things live

| Area | Files |
|---|---|
| Game rules & scoring | `NoNoNo/Models/GameEngine.swift` (deterministic, seeded `SplitMix64`; timed rounds via `Tuning.roundDuration`) |
| Target list (red/green items) | `NoNoNo/Models/Target.swift` |
| Everything he yells | `NoNoNo/Models/QuoteBank.swift` |
| High-score persistence | `NoNoNo/Models/ScoreStore.swift` |
| Screens | `NoNoNo/Views/` (`RootView` routes by `engine.phase`; `GameView` is the board) |
| Target rendering / smash FX | `NoNoNo/Views/GameView.swift` (`TargetView`, `SmashBurstView`, `ShakeEffect`) |
| Josh's faces (photo, flappy head) | `NoNoNo/Views/PhotoFaceView.swift` (`FacePool` maps mood → asset names) |
| Voice (TTS) & sounds (synth PCM) | `NoNoNo/Views/VoiceBox.swift`, `NoNoNo/Views/SoundKit.swift` |
| Live multiplayer | `NoNoNo/Multiplayer/` (`MultipeerSession` transport, `LiveMatchController` state machine, `LiveMessage` wire protocol, `LiveRageOffView` UI) |
| Photos & icons | `NoNoNo/Resources/Assets.xcassets/` (each `face_*.imageset` = one 512px crop) |
| Tests | `NoNoNoTests/` (unit), `NoNoNoUITests/` (launch flows) |

### Adding a target ("no" item or green "he loves it" item)

1. `Target.swift`: add the `case`, list it in the correct branch of `isRage`,
   give it an `emoji`, a `points` tier (rage only: 25 jackpot / 20 / 15 / 10),
   a `label`, and optionally a `caption` (text under the emoji).
2. `QuoteBank.swift`: add 1–3 yell lines to `kindQuotes`. **Mandatory** —
   a test fails the build if a kind has no quotes.
3. Custom art instead of emoji: add a case to `targetFace` in `TargetView`
   (copy `StudentDriverSticker` for drawn art, `.redHair` for a photo).
4. Live mode: add rage kinds to `demandKinds` in `LiveMatchController.swift`
   if they should appear as JOSH DEMANDS callouts.
5. `./trigger-build.sh ship` — tests enforce the conventions.

### Adding a Josh face

Crop to a square PNG (~512px), copy an existing `face_*.imageset` folder in
`Assets.xcassets`, swap the PNG and the filename inside its `Contents.json`,
then add the asset name to the right mood pool in `FacePool`
(`grinning` / `raging` = smashed / `defeated`). A test verifies every pool
name resolves to a real asset.

### Conventions the tests enforce

- Every `TargetKind` has quotes, an emoji, and a label; aloha kinds have no captions.
- Engine changes must keep determinism: same seed → identical round
  (`testSeededStartReplaysIdenticalRounds`).
- UI elements that tests touch carry `accessibilityIdentifier`s
  (`startButton`, `gameBoard`, `scoreLabel`, `liveRageOffButton`, …). On
  iOS 26 sims, query via `descendants(matching: .any)[id]`, not `app.buttons`.

## Building & deploying

Everything runs remotely: `./trigger-build.sh <action>` pushes the current
branch, sends an SQS job to the **mac-builder** daemon, and streams back the
result. The daemon clones the repo, runs `bash build.sh <action>` per
`.mac-builder.yaml`, and uploads artifacts to S3.

| Command | What it does |
|---|---|
| `./trigger-build.sh test` | xcodegen + full XCTest suite (unit + UI, serial on one simulator) |
| `./trigger-build.sh ship` | test → Release archive → signed IPA → **OTA install link on S3** (7-day presigned URLs, printed as `INSTALL_PAGE_URL`) |
| `./trigger-build.sh release` | test → archive → App Store export → **TestFlight upload** |
| `./trigger-build.sh testflight` | same as release but skips tests (don't) |

### S3 / OTA links (ad-hoc installs, no Apple review)

`ship` uploads `builds/nonono/<timestamp>-<sha>/` (IPA + manifest.plist +
install.html) to `s3://cct-golf-builds` and prints a presigned
`INSTALL_PAGE_URL`. Open it in **Safari on the iPhone**, tap Install. Links
expire after 7 days; every ship mints a fresh one. Signing uses the
"debugging" export method, so devices must be registered to team 827WYA3YJJ.

### TestFlight

- Upload: `./trigger-build.sh release`. Build number = max(ASC latest + 1,
  git commit count) — monotonic, never collides.
- Signing/upload is headless: ASC key `MA894X726H` lives on the build Mac at
  `~/.appstoreconnect/private_keys/`. This Linux box has its own ASC API key
  (`~/.appstoreconnect/AuthKey_3W68VH6RT2.p8`, same issuer) for API queries.
- Processing takes ~5–30 min after upload (first build of a new app: up to
  an hour). Verify in App Store Connect → Josh Smash → TestFlight, or via
  `GET /v1/builds?filter[app]=6790039068`.
- **Internal testing**: add ASC team users to an internal group — instant,
  no review, auto-updates.
- **External testing / public link**: fill in Test Information (beta
  description + feedback email) once, add a build to an external group →
  Beta App Review (~24h first time). The public link supports 10,000
  testers — this is how the group chat installs it.
- Gotcha: Xcode 26's altool can exit 0 on a failed upload; if a build never
  appears, re-check the API before re-running.
- The app record itself can only be created in the ASC **web UI** (the API
  has no create; verified). Already done for this app.

### Credentials & infra map

- SQS queue `golf-builds` (us-east-1) → mac-builder daemon → S3
  `cct-golf-builds`. AWS creds come from the local environment.
- ASC issuer `69a6de98-0f77-47e3-e053-5b8c7c11a4d1`; keys as above.
- Team ID `827WYA3YJJ`. SKU `nonono`.

## TODO / ideas

Unfinished things that matter:

- [ ] **Field-test RAGE-OFF LIVE on real phones.** MultipeerConnectivity
      cannot be exercised by CI simulators. Verify: discovery both
      directions, 3–4 player lobbies, host quitting mid-round, a joiner
      dropping (podium currently proceeds after a 6s grace), and demand
      timing feel (12s cadence / 6s window may need tuning).
- [ ] **Set up the TestFlight public link** (Test Information + external
      group + Beta App Review) so the group chat installs without OTA links.
- [ ] **Real Josh audio.** Record him ("no no no", "goddamnit", the intro)
      and play clips via AVAudioPlayer with TTS as fallback. The gag doubles
      in strength with his actual voice.
- [ ] **Live-mode protocol versioning.** `LiveMessage` has no version field;
      mixed-build lobbies could decode garbage. Add a version int to
      `hello`/`roster` and refuse mismatches politely.
- [ ] **Host-drop handling in live mode** — if the host leaves mid-round,
      joiners hang until the round timer ends. Detect and bail to lobby.

Polish that would earn its keep:

- [ ] Smash-juice layer 2: 40ms hit-pause on contact, full-screen "SMASH!"
      flash at combo milestones, haptic intensity scaling with combo,
      persistent cracks on the board where things died.
- [ ] Ginger Mode should tint the photo faces' beard red, not just add 🔥.
- [ ] How-to-play overlay on first launch (three lines, his voice reads it).
- [ ] Pause button during solo runs.
- [ ] Alternate app icons (drag Josh, angel Josh) via `setAlternateIconName`.
- [ ] Daily seeded puzzle + AWS leaderboard, cloned from the citydoku stack
      (API Gateway + Lambda + DynamoDB, ~$0 idle) — the group-chat
      high-score war, async edition.
- [ ] Game Center achievements ("Denied 100 Redheads", "Smacked Shannon 50
      Times", "Survived Full Ralph Mode").
- [ ] More faces: pool is 11; per-event faces (demand-failed Josh, new-high-
      score Josh) would land well.
- [ ] Trim dead code: `FaceView` cartoon is behind a Settings toggle — keep
      or kill deliberately.

Explicitly decided against (don't re-add):

- Pass-the-phone multiplayer (removed; live mode replaced it).
- App Store public release (owner's call: TestFlight only).
- Any "fat people" target content (not negotiable).
