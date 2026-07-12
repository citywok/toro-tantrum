import SwiftUI

struct GameView: View {
    @ObservedObject var engine: GameEngine
    var gingerMode: Bool
    var hapticsOn: Bool

    @State private var quote = "BRING IT."
    @State private var bursts: [Burst] = []

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
        .onReceive(tick) { _ in
            engine.advance(to: Date().timeIntervalSinceReferenceDate)
        }
    }

    private var hud: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(engine.score)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("scoreLabel")
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
                Text(engine.isRageMode ? "🔥 RAGE MODE 🔥" : "R A G E")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.95))
            )
        }
        .padding(.horizontal)
    }

    private var faceArea: some View {
        HStack(alignment: .center, spacing: 12) {
            FaceView(mood: engine.isRageMode ? .raging : .grinning,
                     ginger: gingerMode, size: 92)
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

        if hapticsOn {
            if result.lostLife {
                Haptics.bad()
            } else if result.enteredRageMode {
                Haptics.rage()
            } else {
                Haptics.hit()
            }
        }

        if result.enteredRageMode {
            quote = QuoteBank.rageModeStart.randomElement() ?? "RAGE!!"
        } else {
            quote = QuoteBank.smackQuote(for: target.kind)
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
            Text(kind.emoji).font(.system(size: 34))
        }
        .frame(width: 64, height: 64)
        .contentShape(Circle())
        .scaleEffect(appeared ? 1 : 0.3)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { appeared = true }
        }
        .accessibilityLabel(kind.label)
        .accessibilityIdentifier("target-\(kind.rawValue)")
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
