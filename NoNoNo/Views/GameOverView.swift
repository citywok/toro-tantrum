import SwiftUI

struct GameOverView: View {
    var score: Int
    var bestCombo: Int
    var smacks: Int
    var highScore: Int
    var isNewHighScore: Bool
    var gingerMode: Bool
    var onAgain: () -> Void
    var onMenu: () -> Void

    @State private var insult = QuoteBank.gameOverInsults.randomElement() ?? ""

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            VStack(spacing: -6) {
                Text("GAME OVER,")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text("GODDAMNIT.")
                    .font(.system(size: 46, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: 3)

            FaceView(mood: .defeated, ginger: gingerMode, size: 140)

            Text("\(score)")
                .font(.system(size: 64, weight: .black, design: .rounded))
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

            HStack(spacing: 26) {
                VStack {
                    Text("\(smacks)").font(.title2.weight(.heavy))
                    Text("SMACKS").font(.caption2.bold())
                }
                VStack {
                    Text("x\(bestCombo)").font(.title2.weight(.heavy))
                    Text("BEST COMBO").font(.caption2.bold())
                }
            }
            .foregroundColor(.white.opacity(0.9))

            Text("“\(insult)”")
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
}
