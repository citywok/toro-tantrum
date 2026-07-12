import SwiftUI

struct StartView: View {
    var highScore: Int
    var gingerMode: Bool
    var onStart: () -> Void
    var onSettings: () -> Void

    @State private var wobble = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(8)
                }
                .accessibilityIdentifier("settingsButton")
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: -10) {
                Text("NO NO")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                Text("NO!")
                    .font(.system(size: 92, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 4)
            .rotationEffect(.degrees(wobble ? -2 : 2))
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: wobble)
            .onAppear { wobble = true }

            Text("T H E   R A G E   G A M E")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))

            FaceView(mood: .grinning, ginger: gingerMode, size: 165)

            Text("Smack everything he hates.\nDo NOT touch the mai tai.")
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            Button(action: onStart) {
                Text("TAP TO RAGE")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 44)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.15, blue: 0.10)))
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
            }
            .accessibilityIdentifier("startButton")

            if highScore > 0 {
                Text("HIGH SCORE: \(highScore)")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.yellow)
            }

            Spacer()

            Text("Made with aloha for the angriest man on the island.\nHe is not a redhead. (He is.)")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 6)
        }
        .padding()
    }
}
