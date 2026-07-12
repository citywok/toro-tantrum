import SwiftUI

struct RootView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var scores = ScoreStore()
    @AppStorage("gingerMode") private var gingerMode = false
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = true
    @AppStorage("soundOn") private var soundOn = true
    @State private var showSettings = false
    @State private var showRageOff = false
    @State private var lastGameWasHighScore = false
    @State private var saidIntro = false

    var body: some View {
        ZStack {
            HawaiiBackground(rageMode: engine.isRageMode && engine.phase == .playing)
            switch engine.phase {
            case .ready:
                StartView(
                    highScore: scores.highScore,
                    gingerMode: gingerMode,
                    onStart: {
                        if voiceOn { VoiceBox.shared.sayIntro() }
                        engine.start(at: Date().timeIntervalSinceReferenceDate)
                    },
                    onRageOff: { showRageOff = true },
                    onSettings: { showSettings = true }
                )
            case .playing:
                GameView(engine: engine, gingerMode: gingerMode,
                         hapticsOn: hapticsOn, soundOn: soundOn, voiceOn: voiceOn)
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
                if soundOn { SoundKit.shared.gameOver() }
                if voiceOn {
                    // Let the mistake yell finish before the eulogy.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        if engine.phase == .gameOver { VoiceBox.shared.sayGameOver() }
                    }
                }
            }
        }
        // Every mistake is announced out loud, immediately — including the
        // final one, which is why this lives here and not in GameView.
        .mistakeFeedback(engine: engine, hapticsOn: hapticsOn,
                         soundOn: soundOn, voiceOn: voiceOn)
        .onAppear {
            if voiceOn && !saidIntro {
                saidIntro = true
                VoiceBox.shared.sayIntro()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(gingerMode: $gingerMode, hapticsOn: $hapticsOn,
                         voiceOn: $voiceOn, soundOn: $soundOn)
        }
        .fullScreenCover(isPresented: $showRageOff) {
            RageOffFlowView(gingerMode: gingerMode, hapticsOn: hapticsOn,
                            soundOn: soundOn, voiceOn: voiceOn, scores: scores,
                            onExit: { showRageOff = false })
        }
        .statusBarHidden(true)
    }
}
