import SwiftUI

struct GameView: View {
    @ObservedObject var engine: GameEngine
    var gingerMode: Bool
    var hapticsOn: Bool
    var soundOn: Bool
    var voiceOn: Bool
    /// Live multiplayer hook: called after every landed smack.
    var onSmack: ((TargetKind, GameEngine.SmackResult) -> Void)?

    @State private var quote = QuoteBank.intro
    @State private var bursts: [Burst] = []
    @State private var talking = false
    @State private var talkUntil = Date.distantPast

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    struct Burst: Identifiable, Equatable {
        let id: UUID
        let text: String
        let x: CGFloat
        let y: CGFloat
        let color: Color
    }

    var body: some View {
        VStack(spacing: 8) {
            hud

            GeometryReader { geo in
                ZStack {
                    ForEach(engine.targets) { target in
                        TargetView(kind: target.kind)
                            .position(x: target.x * geo.size.width,
                                      y: target.y * geo.size.height)
                            .onTapGesture { smack(target, in: geo.size) }
                    }
                    ForEach(bursts) { burst in
                        Text(burst.text)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(burst.color)
                            .shadow(color: .black.opacity(0.4), radius: 0, x: 1, y: 2)
                            .position(x: burst.x, y: burst.y)
                            .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: engine.targets)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("gameBoard")

            faceArea
        }
        .padding(.top, 8)
        .overlay(rageBorder)
        .onAppear { flapFor(1.6) }
        .onReceive(tick) { _ in
            engine.advance(to: Date().timeIntervalSinceReferenceDate)
            let nowTalking = Date() < talkUntil
            if talking != nowTalking { talking = nowTalking }
        }
        // Any mistake — bad tap or escaped target — gets the catchphrase,
        // immediately. Haptics/sounds/voice live in RootView so they survive
        // the final life loss removing this view.
        .onChange(of: engine.lastLifeLoss) { event in
            guard let event else { return }
            quote = event.cause == .badTap ? QuoteBank.badTapMistake : QuoteBank.mistake
            flapFor(1.0)
        }
    }

    private func flapFor(_ seconds: TimeInterval) {
        talkUntil = Date().addingTimeInterval(seconds)
        talking = true
    }

    private var hud: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(engine.score)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("scoreLabel")
                if let timeLeft = engine.timeLeft {
                    Text("⏱\(Int(timeLeft.rounded(.up)))")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(timeLeft < 10 ? .red : .white.opacity(0.9))
                        .accessibilityIdentifier("timerLabel")
                }
                if engine.combo >= 2 {
                    Text("x\(engine.comboMultiplier) · \(engine.combo) COMBO")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<engine.tuning.startLives, id: \.self) { i in
                        Text("🌺")
                            .font(.title3)
                            .opacity(i < engine.lives ? 1 : 0.18)
                    }
                }
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.3))
                GeometryReader { g in
                    Capsule()
                        .fill(LinearGradient(colors: [.yellow, .orange, .red],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, g.size.width * (engine.isRageMode ? 1 : engine.rage)))
                        .animation(.easeOut(duration: 0.2), value: engine.rage)
                }
            }
            .frame(height: 13)
            .overlay(
                Text(engine.isRageMode ? "🍹 JOSH SMASHED 🍹" : "SMASH-O-METER")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.95))
            )
        }
        .padding(.horizontal)
    }

    private var faceArea: some View {
        HStack(alignment: .center, spacing: 12) {
            CharacterFace(mood: engine.isRageMode ? .raging : .grinning,
                          ginger: gingerMode, size: 92, talking: talking)
            SpeechBubble(text: quote)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .frame(height: 118)
    }

    @ViewBuilder
    private var rageBorder: some View {
        if engine.isRageMode {
            Rectangle()
                .strokeBorder(Color.red.opacity(0.75), lineWidth: 6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func smack(_ target: SpawnedTarget, in size: CGSize) {
        let now = Date().timeIntervalSinceReferenceDate
        guard let result = engine.smack(target.id, at: now) else { return }
        onSmack?(target.kind, result)

        // Mistakes (lostLife) are handled by the lastLifeLoss watchers.
        if !result.lostLife {
            if hapticsOn {
                result.enteredRageMode ? Haptics.rage() : Haptics.hit()
            }
            if soundOn {
                result.enteredRageMode
                    ? SoundKit.shared.rageStart()
                    : SoundKit.shared.smack(combo: engine.combo)
            }
            // Only red targets reach here now — green taps always lose a life
            // and get their "god damn it!" from the lastLifeLoss watcher.
            if voiceOn {
                result.enteredRageMode ? VoiceBox.shared.sayRage() : VoiceBox.shared.sayNo()
            }
            if result.enteredRageMode {
                quote = QuoteBank.rageModeStart.randomElement() ?? "JOSH SMASHED!!"
            } else {
                quote = QuoteBank.smackQuote(for: target.kind)
            }
            flapFor(result.enteredRageMode ? 1.2 : 0.5)
        }

        let burst = Burst(
            id: UUID(),
            text: result.lostLife ? "\(result.pointsAwarded)" : "+\(result.pointsAwarded)",
            x: target.x * size.width,
            y: target.y * size.height,
            color: result.lostLife ? .red : .yellow
        )
        withAnimation { bursts.append(burst) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { bursts.removeAll { $0.id == burst.id } }
        }
    }
}

struct TargetView: View {
    let kind: TargetKind
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(kind.isRage
                      ? Color.white.opacity(0.88)
                      : Color(red: 0.62, green: 0.95, blue: 0.75).opacity(0.92))
                .overlay(
                    Circle().stroke(kind.isRage
                                    ? Color(red: 0.80, green: 0.20, blue: 0.10)
                                    : Color(red: 0.05, green: 0.45, blue: 0.28),
                                    lineWidth: 3)
                )
            targetFace
        }
        .frame(width: 83, height: 83)
        .contentShape(Circle())
        .scaleEffect(appeared ? 1 : 0.3)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { appeared = true }
        }
        .accessibilityLabel(kind.label)
        .accessibilityIdentifier("target-\(kind.rawValue)")
    }

    @ViewBuilder
    private var targetFace: some View {
        switch kind {
        case .newDriver:
            StudentDriverSticker()
        case .kids:
            VStack(spacing: -2) {
                SwaddledBaby()
                Text("KIDS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.black)
            }
        default:
            if let caption = kind.caption {
                VStack(spacing: -1) {
                    Text(kind.emoji).font(.system(size: 31))
                    Text(caption)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 3)
            } else {
                Text(kind.emoji).font(.system(size: 44))
            }
        }
    }
}

/// The yellow menace itself.
struct StudentDriverSticker: View {
    var body: some View {
        VStack(spacing: -1) {
            Text("STUDENT")
            Text("DRIVER")
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundColor(.black)
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(red: 1.0, green: 0.84, blue: 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black, lineWidth: 2))
        .rotationEffect(.degrees(-6))
    }
}

/// A baby, swaddled. Menace level: brunch.
struct SwaddledBaby: View {
    var body: some View {
        VStack(spacing: -8) {
            Text("👶").font(.system(size: 24))
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(red: 0.66, green: 0.85, blue: 0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 11).stroke(.black, lineWidth: 1.5)
                )
                .overlay(
                    // Blanket wrap line
                    Path { path in
                        path.move(to: CGPoint(x: 4, y: 8))
                        path.addLine(to: CGPoint(x: 30, y: 20))
                    }
                    .stroke(.black.opacity(0.35), lineWidth: 1.5)
                )
                .frame(width: 34, height: 26)
        }
    }
}

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .italic()
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black, lineWidth: 2))
            )
            .accessibilityIdentifier("quoteLabel")
    }
}
