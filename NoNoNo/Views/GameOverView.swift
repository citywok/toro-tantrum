import SwiftUI

struct GameOverView: View {
    var score: Int
    var bestCombo: Int
    var smacks: Int
    var totalTaps: Int
    var rageModeCount: Int
    var highScore: Int
    var isNewHighScore: Bool
    var gingerMode: Bool
    var onAgain: () -> Void
    var onMenu: () -> Void

    @State private var insult = QuoteBank.gameOverInsults.randomElement() ?? ""
    @State private var continueCountdown = 10
    @State private var screenPhase: ScreenPhase = .continuePrompt

    private let continueTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    enum ScreenPhase { case continuePrompt, stats }

    var body: some View {
        ZStack {
            // ── Stats screen (always present, dimmed behind overlay) ──
            statsContent
                .opacity(screenPhase == .stats ? 1 : 0.15)
                .blur(radius: screenPhase == .continuePrompt ? 8 : 0)
                .animation(.easeInOut(duration: 0.4), value: screenPhase)

            // ── Continue overlay ──
            if screenPhase == .continuePrompt {
                VStack(spacing: 18) {
                    Spacer()

                    Text("CONTINUE?")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 3, y: 4)

                    Text("\(continueCountdown)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 3, y: 4)

                    Text("Lives lost. Game not saved.")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: {
                        withAnimation { screenPhase = .stats }
                        onAgain()
                    }) {
                        Text("TAP TO CONTINUE")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 44)
                            .background(Capsule().fill(Color(red: 0.10, green: 0.55, blue: 0.25)))
                            .overlay(Capsule().stroke(.white, lineWidth: 3))
                    }

                    Button(action: {
                        withAnimation { screenPhase = .stats }
                    }) {
                        Text("let me rest (stats)")
                            .font(.footnote.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                    }

                    Spacer()
                }
                .padding()
                .transition(.opacity)
            }
        }
        .onReceive(continueTimer) { _ in
            guard screenPhase == .continuePrompt else { return }
            if continueCountdown > 1 {
                continueCountdown -= 1
            } else {
                withAnimation { screenPhase = .stats }
            }
        }
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 12) {
            Spacer()

            VStack(spacing: -6) {
                Text("GAME OVER,")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text("NOOOOOO.")
                    .font(.system(size: 46, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: 3)

            CharacterFace(mood: .defeated, ginger: gingerMode, size: 130)

            Text("\(score)")
                .font(.system(size: 60, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
                .accessibilityIdentifier("finalScoreLabel")

            if isNewHighScore {
                Text("🏆 NEW HIGH SCORE 🏆")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.white)
            } else {
                Text("HIGH SCORE: \(highScore)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.85))
            }

            // ── Post-game stats breakdown ──
            StatsRow(items: [
                ("\(smacks)", "SMACKS"),
                ("x\(bestCombo)", "BEST COMBO"),
                (accuracy, "ACCURACY"),
                ("\(rageModeCount)", "RAGE MODES"),
            ])
            .foregroundColor(.white.opacity(0.9))

            Text("\(insult)")
                .font(.callout.italic())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 32)

            Button(action: onAgain) {
                Text("AGAIN. NOW.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
            }
            .accessibilityIdentifier("againButton")

            Button(action: onMenu) {
                Text("calm down (menu)")
                    .font(.footnote.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
            }
            .accessibilityIdentifier("menuButton")

            Spacer()
        }
        .padding()
    }

    private var accuracy: String {
        guard totalTaps > 0 else { return "—" }
        let pct = Double(smacks) / Double(totalTaps) * 100
        return String(format: "%.0f%%", pct)
    }
}

/// A horizontal row of stat items.
struct StatsRow: View {
    struct Item: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    let items: [(String, String)]

    private var statItems: [Item] {
        items.map { Item(value: $0.0, label: $0.1) }
    }

    var body: some View {
        HStack(spacing: 22) {
            ForEach(statItems) { item in
                VStack {
                    Text(item.value).font(.title3.weight(.heavy))
                    Text(item.label).font(.caption2.bold())
                }
            }
        }
    }
}
