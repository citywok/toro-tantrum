import SwiftUI

struct RootView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var scores = ScoreStore()
    @AppStorage("gingerMode") private var gingerMode = false
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = true
    @AppStorage("soundOn") private var soundOn = true
    @AppStorage("musicOn") private var musicOn = true
    @State private var showSettings = false
    @State private var showMultiplayer = false
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
                    onLiveRageOff: { showMultiplayer = true },
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
                    totalTaps: engine.totalTaps,
                    rageModeCount: engine.rageModeCount,
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
            // Background music
            handleBackgroundMusic(for: phase)
        }
        // Every mistake is announced out loud, immediately — including the
        // final one, which is why this lives here and not in GameView.
        .mistakeFeedback(engine: engine, hapticsOn: hapticsOn,
                         soundOn: soundOn, voiceOn: voiceOn)
        .onAppear {
            if voiceOn && !saidIntro {
                saidIntro = true
                VoiceBox.shared.sayJeMapelle()
            }
            // Start music when the app appears on the start screen
            if musicOn {
                SoundKit.shared.startMusic()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(gingerMode: $gingerMode, hapticsOn: $hapticsOn,
                         voiceOn: $voiceOn, soundOn: $soundOn, musicOn: $musicOn)
        }
        .fullScreenCover(isPresented: $showMultiplayer) {
            LiveRageOffView(gingerMode: gingerMode, hapticsOn: hapticsOn,
                            soundOn: soundOn, voiceOn: voiceOn, musicOn: musicOn,
                            scores: scores,
                            onExit: { showMultiplayer = false })
        }
        .onChange(of: showMultiplayer) { showing in
            if showing {
                // Stop background music when entering multiplayer
                SoundKit.shared.stopMusic()
            } else {
                // Restart music when returning to main menu
                handleBackgroundMusic(for: engine.phase)
            }
        }
        .onChange(of: musicOn) { enabled in
            if enabled {
                handleBackgroundMusic(for: engine.phase)
            } else {
                SoundKit.shared.stopMusic()
            }
        }
        .statusBarHidden(true)
    }

    private func handleBackgroundMusic(for phase: GamePhase) {
        switch phase {
        case .ready, .playing:
            if musicOn {
                SoundKit.shared.startMusic()
            }
        case .gameOver:
            SoundKit.shared.stopMusic()
        }
    }
}
