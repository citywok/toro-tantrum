import SwiftUI

/// MULTIPLAYER: own phones, nearby, same seeded round, all at once.
struct LiveRageOffView: View {
    var gingerMode: Bool
    var hapticsOn: Bool
    var soundOn: Bool
    var voiceOn: Bool
    var musicOn: Bool
    @ObservedObject var scores: ScoreStore
    var onExit: () -> Void

    @StateObject private var match = LiveMatchController()
    @AppStorage("playerName") private var playerName = ""
    @State private var picked = false
    @State private var recordedThisRound = false

    var body: some View {
        ZStack {
            HawaiiBackground(rageMode: match.engine.isRageMode && match.stage == .playing)
            switch match.stage {
            case .lobby: lobbyView
            case .countdown: countdownView
            case .playing: playingView
            case .podium: podiumView
            }
        }
        .mistakeFeedback(engine: match.engine, hapticsOn: hapticsOn,
                         soundOn: soundOn, voiceOn: voiceOn)
        .onChange(of: match.stage) { stage in
            switch stage {
            case .countdown:
                recordedThisRound = false
                SoundKit.shared.stopMusic()
            case .podium:
                SoundKit.shared.stopMusic()
                if !recordedThisRound {
                    recordedThisRound = true
                    scores.record(score: match.engine.score, smacks: match.engine.smacks)
                    if soundOn { SoundKit.shared.gameOver() }
                    if voiceOn, let winner = match.ranked.first?.name {
                        VoiceBox.shared.speak("\(winner) wins. everyone else... god damn it.")
                    }
                }
            case .lobby, .playing:
                if musicOn && !SoundKit.shared.musicPlaying {
                    SoundKit.shared.startMusic()
                }
            }
        }
        .onAppear {
            if playerName.trimmingCharacters(in: .whitespaces).isEmpty,
               let guess = PlayerNameGuess.fromDevice() {
                playerName = guess.uppercased()
            }
            // Start music on the lobby screen
            if musicOn {
                SoundKit.shared.startMusic()
            }
        }
        .onDisappear {
            match.leave()
            SoundKit.shared.stopMusic()
        }
        .statusBarHidden(true)
    }

    // MARK: - Lobby

    private var lobbyView: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    match.leave()
                    onExit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .padding(10)
                }
                .accessibilityIdentifier("exitLiveButton")
                Spacer()
            }
            .padding(.horizontal, 8)

            Text("MULTIPLAYER")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 4)

            Text("Own phones. Same room. Same 60 seconds.\nWhen JOSH DEMANDS, the room enforces it.")
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            TextField("YOUR NAME", text: $playerName)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .disabled(picked)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(picked ? 0.6 : 0.94)))
                .padding(.horizontal, 60)
                .accessibilityIdentifier("liveNameField")

            if !picked {
                HStack(spacing: 14) {
                    Button {
                        picked = true
                        match.host(name: playerName)
                    } label: {
                        Text("HOST")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 13)
                            .padding(.horizontal, 34)
                            .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                            .overlay(Capsule().stroke(.white, lineWidth: 3))
                    }
                    .accessibilityIdentifier("hostButton")

                    Button {
                        picked = true
                        match.join(name: playerName)
                    } label: {
                        Text("JOIN")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 13)
                            .padding(.horizontal, 34)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                            .overlay(Capsule().stroke(.white, lineWidth: 3))
                    }
                    .accessibilityIdentifier("joinButton")
                }
            }

            Text(match.connectionStatus)
                .font(.caption.bold())
                .foregroundColor(.yellow)

            if !match.roster.isEmpty {
                VStack(spacing: 6) {
                    ForEach(match.roster, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(.white.opacity(0.9)))
                    }
                }
                .padding(.horizontal, 60)
            }

            if match.isHost {
                Button {
                    match.startMatch()
                } label: {
                    Text("START (\(match.roster.count) PLAYERS)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Capsule().fill(
                            (2...4).contains(match.roster.count)
                                ? Color(red: 0.85, green: 0.15, blue: 0.10)
                                : Color.gray.opacity(0.5)))
                        .overlay(Capsule().stroke(.white, lineWidth: 3))
                }
                .disabled(!(2...4).contains(match.roster.count))
                .accessibilityIdentifier("startLiveButton")
            }

            Spacer()

            CharacterFace(mood: .grinning, ginger: gingerMode, size: 110)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 10) {
            Text("GET READY TO RAGE")
                .font(.headline.weight(.heavy))
                .foregroundColor(.white)
            Text("\(max(match.countdown, 1))")
                .font(.system(size: 140, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.4), radius: 0, x: 4, y: 5)
            CharacterFace(mood: .grinning, ginger: gingerMode, size: 130, talking: true)
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        ZStack(alignment: .top) {
            GameView(engine: match.engine, gingerMode: gingerMode,
                     hapticsOn: hapticsOn, soundOn: soundOn, voiceOn: voiceOn,
                     onSmack: { kind, result in match.playerSmacked(kind: kind, result: result) })

            VStack(spacing: 6) {
                if !match.opponentScores.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(match.opponentScores.sorted(by: { $0.key < $1.key }), id: \.key) { name, score in
                            Text("\(name) \(score)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Capsule().fill(Color.black.opacity(0.45)))
                        }
                    }
                }
                if let demand = match.activeDemand {
                    Text("🗣 JOSH DEMANDS: \(demand.player) → SMACK \(demand.kind.emoji) \(demand.kind.caption ?? demand.kind.label.uppercased())!")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.yellow))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black, lineWidth: 2))
                        .accessibilityIdentifier("demandBanner")
                } else if let flash = match.flash {
                    Text(flash)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                }
            }
            .padding(.top, 96)
            .padding(.horizontal)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("MULTIPLAYER RESULTS")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: 3)

            let medals = ["🏆", "🥈", "🥉", "😤"]
            VStack(spacing: 8) {
                ForEach(Array(match.ranked.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text(medals[min(index, medals.count - 1)])
                        Text(entry.name)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
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

            if let loser = match.ranked.last, match.ranked.count > 1 {
                Text("“\(QuoteBank.trashTalk(for: loser.name))”")
                    .font(.callout.italic())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            CharacterFace(mood: .defeated, ginger: gingerMode, size: 110)

            if match.isHost {
                Button {
                    match.startMatch()
                } label: {
                    Text("REMATCH. NOW.")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 13)
                        .padding(.horizontal, 34)
                        .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                        .overlay(Capsule().stroke(.white, lineWidth: 3))
                }
                .accessibilityIdentifier("liveRematchButton")
            } else {
                Text("waiting for the host to rematch...")
                    .font(.footnote.bold())
                    .foregroundColor(.white.opacity(0.8))
            }

            Button {
                match.leave()
                onExit()
            } label: {
                Text("done (for now)")
                    .font(.footnote.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
            }
            .accessibilityIdentifier("liveDoneButton")

            Spacer()
        }
    }
}
