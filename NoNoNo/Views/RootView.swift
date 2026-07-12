import SwiftUI

struct RootView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var scores = ScoreStore()
    @AppStorage("gingerMode") private var gingerMode = false
    @AppStorage("hapticsOn") private var hapticsOn = true
    @State private var showSettings = false
    @State private var lastGameWasHighScore = false

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
        .sheet(isPresented: $showSettings) {
            SettingsView(gingerMode: $gingerMode, hapticsOn: $hapticsOn)
        }
        .statusBarHidden(true)
    }
}
