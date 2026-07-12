import SwiftUI

/// Pass-the-phone multiplayer: everyone plays the identical seeded
/// 60-second round, the app trash-talks between turns, loser gets yelled at.
struct RageOffFlowView: View {
    var gingerMode: Bool
    var hapticsOn: Bool
    var soundOn: Bool
    var voiceOn: Bool
    @ObservedObject var scores: ScoreStore
    var onExit: () -> Void

    @StateObject private var engine = GameEngine(tuning: {
        var tuning = Tuning()
        tuning.roundDuration = 60
        return tuning
    }())

    @State private var stage: Stage = .setup
    @State private var names = ["PLAYER 1", "PLAYER 2"]
    @State private var results: [Int] = []
    @State private var current = 0
    @State private var matchSeed: UInt64 = 0

    enum Stage {
        case setup, handoff, playing, podium
    }

    var body: some View {
        ZStack {
            HawaiiBackground(rageMode: engine.isRageMode && stage == .playing)
            switch stage {
            case .setup: setupView
            case .handoff: handoffView
            case .playing:
                GameView(engine: engine, gingerMode: gingerMode,
                         hapticsOn: hapticsOn, soundOn: soundOn, voiceOn: voiceOn)
            case .podium: podiumView
            }
        }
        .mistakeFeedback(engine: engine, hapticsOn: hapticsOn,
                         soundOn: soundOn, voiceOn: voiceOn)
        .onChange(of: engine.phase) { phase in
            guard stage == .playing, phase == .gameOver else { return }
            finishTurn()
        }
        .statusBarHidden(true)
    }

    // MARK: - Match flow

    private func startMatch() {
        for index in names.indices where names[index].trimmingCharacters(in: .whitespaces).isEmpty {
            names[index] = "PLAYER \(index + 1)"
        }
        results = []
        current = 0
        matchSeed = UInt64.random(in: .min ... .max)
        stage = .handoff
    }

    private func startTurn() {
        if voiceOn { VoiceBox.shared.speak("\(names[current])... go!") }
        engine.start(at: Date().timeIntervalSinceReferenceDate, seed: matchSeed)
        stage = .playing
    }

    private func finishTurn() {
        results.append(engine.score)
        scores.record(score: engine.score, smacks: engine.smacks)
        if soundOn { SoundKit.shared.gameOver() }
        if results.count < names.count {
            current = results.count
            stage = .handoff
        } else {
            stage = .podium
            if voiceOn, let winner = ranked.first?.name {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    VoiceBox.shared.speak("\(winner) wins. everyone else... god damn it.")
                }
            }
        }
    }

    private var ranked: [(name: String, score: Int)] {
        zip(names, results).map { (name: $0, score: $1) }.sorted { $0.score > $1.score }
    }

    // MARK: - Screens

    private var setupView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .padding(10)
                }
                .accessibilityIdentifier("exitRageOffButton")
                Spacer()
            }
            .padding(.horizontal, 8)

            Text("RAGE-OFF")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 4)

            Text("Same targets. Same 60 seconds.\nPass the phone. Loser gets yelled at.")
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                Button {
                    if names.count > 2 { names.removeLast() }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title).foregroundColor(.white)
                }
                .accessibilityIdentifier("removePlayerButton")
                Text("\(names.count) PLAYERS")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.white)
                Button {
                    if names.count < 4 { names.append("PLAYER \(names.count + 1)") }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.white)
                }
                .accessibilityIdentifier("addPlayerButton")
            }

            VStack(spacing: 10) {
                ForEach(names.indices, id: \.self) { index in
                    TextField("PLAYER \(index + 1)", text: $names[index])
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .textContentType(index == 0 ? .givenName : .name)
                        .autocorrectionDisabled()
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.94)))
                }
            }
            .padding(.horizontal, 44)
            .onAppear {
                // The phone's owner is holding it, so they're player 1.
                if names.first == "PLAYER 1", let guess = PlayerNameGuess.fromDevice() {
                    names[0] = guess.uppercased()
                }
            }

            Button(action: startMatch) {
                Text("START THE RAGE-OFF")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 36)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
            }
            .accessibilityIdentifier("startMatchButton")

            Spacer()
        }
        .padding(.top, 8)
    }

    private var handoffView: some View {
        VStack(spacing: 16) {
            Spacer()

            if current > 0 {
                VStack(spacing: 6) {
                    Text("\(names[current - 1]) SCORED \(results[current - 1]).")
                        .font(.headline.weight(.heavy))
                    Text("“\(QuoteBank.trashTalk(for: names[current - 1]))”")
                        .font(.callout.italic())
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            }

            Text("PASS THE PHONE TO")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.85))

            Text(names[current])
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 2, y: 3)

            CharacterFace(mood: .grinning, ginger: gingerMode, size: 150)

            Button(action: startTurn) {
                Text("READY. LET'S GO.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 40)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
            }
            .accessibilityIdentifier("readyButton")

            Spacer()
        }
    }

    private var podiumView: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("RAGE-OFF RESULTS")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: 3)

            let medals = ["🏆", "🥈", "🥉", "😤"]
            VStack(spacing: 8) {
                ForEach(Array(ranked.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text(medals[min(index, medals.count - 1)])
                        Text(entry.name)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer()
                        Text("\(entry.score)")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.94)))
                }
            }
            .padding(.horizontal, 36)

            if let loser = ranked.last, ranked.count > 1 {
                Text("“\(QuoteBank.trashTalk(for: loser.name))”")
                    .font(.callout.italic())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            CharacterFace(mood: .defeated, ginger: gingerMode, size: 110)

            Button(action: startMatch) {
                Text("REMATCH. NOW.")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 34)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
            }
            .accessibilityIdentifier("rematchButton")

            Button(action: onExit) {
                Text("done (for now)")
                    .font(.footnote.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
            }
            .accessibilityIdentifier("doneButton")

            Spacer()
        }
    }
}
