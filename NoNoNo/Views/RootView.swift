import SwiftUI

struct RootView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var scores = ScoreStore()
    @AppStorage("gingerMode") private var gingerMode = false
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = true
    @State private var showSettings = false
    @State private var lastGameWasHighScore = false
    @State private var prevLives = Tuning().startLives

    var body: some View {
        ZStack {
            HawaiiBackground(rageMode: engine.isRageMode && engine.phase == .playing)
            switch engine.phase {
            case .ready:
                StartView(
                    highScore: scores.highScore,
                    gingerMode: gingerMode,
                    onStart: { engine.start(at: Date().timeIntervalSinceReferenceDate) },
                    onSettings: { showSettings = true }
                )
            case .playing:
                GameView(engine: engine, gingerMode: gingerMode, hapticsOn: hapticsOn)
            case .gameOver:
                GameOverView(
                    score: engine.score,
                    bestCombo: engine.bestCombo,
                    smacks: engine.smacks,
                    highScore: scores.highScore,
                    isNewHighScore: lastGameWasHighScore,
                    gingerMode: gingerMode,
                    onAgain: { engine.start(at: Date().timeIntervalSinceReferenceDate) },
                    onMenu: { engine.reset() }
                )
            }
        }
        .onChange(of: engine.phase) { phase in
            if phase == .gameOver {
                lastGameWasHighScore = scores.record(score: engine.score, smacks: engine.smacks)
            }
        }
        // Every mistake is announced out loud, immediately — including the
        // final one, which is why this lives here and not in GameView.
        .onChange(of: engine.lives) { newLives in
            if newLives < prevLives && voiceOn {
                VoiceBox.shared.sayNo()
            }
            prevLives = newLives
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(gingerMode: $gingerMode, hapticsOn: $hapticsOn, voiceOn: $voiceOn)
        }
        .statusBarHidden(true)
    }
}
