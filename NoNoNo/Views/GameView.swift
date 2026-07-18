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
    @State private var smashes: [SmashBurst] = []
    @State private var shakePhase: CGFloat = 0
    @State private var talking = false
    @State private var talkUntil = Date.distantPast
    @State private var lastComboValue = 0
    @State private var comboCallout: (String, Color)? = nil
    @State private var extraLifeCallout = false
    @State private var pulseOpacity: CGFloat = 0.6
    @State private var lastSmackPos: CGPoint = .zero

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
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.3).combined(with: .opacity),
                                removal: .scale(scale: 0.2).combined(with: .opacity)))
                    }
                    ForEach(smashes) { smash in
                        SmashBurstView(emoji: smash.emoji)
                            .position(x: smash.x, y: smash.y)
                    }
                    ForEach(bursts) { burst in
                        BurstView(text: burst.text, color: burst.color, x: burst.x, y: burst.y)
                    }
                    // ── Arcade countdown overlay ──
                    if engine.countdownSeconds > 0 {
                        ZStack {
                            Color.black.opacity(0.3)
                            Text(engine.countdownSeconds > 1 ? "\(engine.countdownSeconds)" : "GO!")
                                .font(.system(size: 100, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 0, x: 4, y: 6)
                        }
                        .transition(.opacity)
                    }
                    // ── Combo milestone callout (anchored at last smack) ──
                    if let (text, color) = comboCallout {
                        Text(text)
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundColor(color)
                            .shadow(color: .black.opacity(0.6), radius: 0, x: 3, y: 4)
                            .position(x: lastSmackPos.x, y: lastSmackPos.y)
                            .transition(.scale.combined(with: .opacity))
                    }
                    // ── Extra life celebration (anchored at last smack) ──
                    if extraLifeCallout {
                        Text("+1 ❤️")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.green)
                            .shadow(color: .black.opacity(0.5), radius: 0, x: 3, y: 4)
                            .position(x: lastSmackPos.x, y: lastSmackPos.y)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: engine.targets)
            }
            .modifier(ShakeEffect(animatableData: shakePhase))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("gameBoard")

            faceArea
        }
        .padding(.top, 8)
        .overlay(rageBorder)
        .onAppear {
            flapFor(1.6)
            updateMusicIntensity()
        }
        .onReceive(tick) { _ in
            engine.advance(to: Date().timeIntervalSinceReferenceDate)
            let nowTalking = Date() < talkUntil
            if talking != nowTalking { talking = nowTalking }
        }
        // Any mistake — bad tap or escaped target — gets the catchphrase
        // and a board shake. Haptics/sounds/voice live in RootView so they
        // survive the final life loss removing this view.
        .onChange(of: engine.lastLifeLoss) { event in
            guard let event else { return }
            quote = event.cause == .badTap ? QuoteBank.badTapMistake : QuoteBank.mistake
            withAnimation(.linear(duration: 0.22)) {
                shakePhase += 3
            }
            flapFor(1.0)
        }
        // ── Combo milestone detection ──
        .onChange(of: engine.combo) { newCombo in
            let prev = lastComboValue
            lastComboValue = newCombo
            // Combo broken?
            if newCombo < prev && prev >= 5 {
                withAnimation {
                    comboCallout = ("COMBO BROKEN!", .red)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation { comboCallout = nil }
                }
            } else if newCombo >= 20 && prev < 20 {
                withAnimation { comboCallout = ("MONSTER COMBO!!!", .purple) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { comboCallout = nil }
                }
                if voiceOn { VoiceBox.shared.sayToro() }
            } else if newCombo >= 15 && prev < 15 {
                withAnimation { comboCallout = ("AMAZING!", .orange) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation { comboCallout = nil }
                }
                if voiceOn { VoiceBox.shared.sayToro() }
            } else if newCombo >= 10 && prev < 10 {
                withAnimation { comboCallout = ("GREAT!", .yellow) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { comboCallout = nil }
                }
                if voiceOn { VoiceBox.shared.sayToro() }
            } else if newCombo >= 5 && prev < 5 {
                withAnimation { comboCallout = ("NICE!", .green) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation { comboCallout = nil }
                }
            }
            // ── Dynamic music intensity ──
            updateMusicIntensity()
        }
        // ── Extra life celebration ──
        .onChange(of: engine.extraLifeCount) { _ in
            withAnimation {
                extraLifeCallout = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { extraLifeCallout = false }
            }
        }
        // ── Dynamic music intensity on rage mode toggle ──
        .onChange(of: engine.isRageMode) { _ in
            updateMusicIntensity()
        }
    }

    private func flapFor(_ seconds: TimeInterval) {
        talkUntil = Date().addingTimeInterval(seconds)
        talking = true
    }

    private func updateMusicIntensity() {
        if engine.isRageMode {
            SoundKit.shared.setMusicIntensity(.rage)
        } else if engine.combo >= 10 {
            SoundKit.shared.setMusicIntensity(.intense)
        } else {
            SoundKit.shared.setMusicIntensity(.normal)
        }
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
                        Text("🥚")
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
                Text(engine.isRageMode ? "🍣 LAP TORO TIME 🍣" : "NUG-O-METER")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.95))
            )
            // ── Rage meter pulse when near full ──
            .overlay(
                Group {
                    if engine.rage > 0.8 && !engine.isRageMode {
                        Capsule()
                            .stroke(Color.yellow, lineWidth: 2.5)
                            .opacity(pulseOpacity)
                    }
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.15
                }
            }
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

        // Remember the last smack location for anchoring combo callouts
        lastSmackPos = CGPoint(x: target.x * size.width, y: target.y * size.height)

        // Impact: explosion + debris at the point of contact, board shake.
        // Mistakes shake harder — you FELT that one.
        withAnimation(.linear(duration: 0.18)) {
            shakePhase += result.lostLife ? 2 : 1
        }
        let smash = SmashBurst(id: UUID(), emoji: target.kind.emoji,
                               x: target.x * size.width, y: target.y * size.height)
        smashes.append(smash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            smashes.removeAll { $0.id == smash.id }
        }

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
                quote = QuoteBank.rageModeStart.randomElement() ?? "toro tantrum"
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

struct SmashBurst: Identifiable, Equatable {
    let id: UUID
    let emoji: String
    let x: CGFloat
    let y: CGFloat
}

/// 💥 at the impact point, with bits of the victim flying off and falling.
struct SmashBurstView: View {
    let emoji: String
    @State private var boom = false

    var body: some View {
        ZStack {
            Text("💥")
                .font(.system(size: 60))
                .scaleEffect(boom ? 1.4 : 0.4)
                .opacity(boom ? 0 : 1)
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i) / 5.0 * 2 * .pi + 0.45
                Text(emoji)
                    .font(.system(size: 15))
                    .offset(x: boom ? cos(angle) * 54 : 0,
                            y: boom ? sin(angle) * 54 + 22 : 0)
                    .rotationEffect(.degrees(boom ? Double(i * 137) : 0))
                    .scaleEffect(boom ? 0.4 : 1)
                    .opacity(boom ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { boom = true }
        }
    }
}

/// Score popup that flies upward and fades out.
struct BurstView: View {
    let text: String
    let color: Color
    let x: CGFloat
    let y: CGFloat

    @State private var flyOffset: CGFloat = 0
    @State private var opacity: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(color)
            .shadow(color: .black.opacity(0.4), radius: 0, x: 1, y: 2)
            .position(x: x, y: y + flyOffset)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    flyOffset = -44
                    opacity = 0
                }
            }
    }
}

/// Quick horizontal jolt; each increment of animatableData is one hit.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
            y: 0))
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
