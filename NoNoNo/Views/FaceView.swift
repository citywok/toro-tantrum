import SwiftUI

/// Him. Bald, furious, smiling about it. Flat construction-paper style.
struct FaceView: View {
    enum Mood {
        case grinning
        case raging
        case defeated
    }

    var mood: Mood = .grinning
    var ginger: Bool = false
    var size: CGFloat = 160

    private var skin: Color { Color(red: 0.99, green: 0.85, blue: 0.66) }
    private var stubble: Color {
        ginger ? Color(red: 0.95, green: 0.25, blue: 0.05)
               : Color(red: 0.78, green: 0.42, blue: 0.22)
    }

    var body: some View {
        let s = size
        ZStack {
            // Ears
            Circle()
                .fill(skin)
                .overlay(Circle().stroke(.black, lineWidth: s * 0.018))
                .frame(width: s * 0.18, height: s * 0.18)
                .offset(x: -s * 0.44)
            Circle()
                .fill(skin)
                .overlay(Circle().stroke(.black, lineWidth: s * 0.018))
                .frame(width: s * 0.18, height: s * 0.18)
                .offset(x: s * 0.44)

            // Gloriously bald head
            Circle()
                .fill(skin)
                .overlay(Circle().stroke(.black, lineWidth: s * 0.022))
                .frame(width: s * 0.92, height: s * 0.92)

            // Ginger Mode: the truth comes out
            if ginger {
                Text("🔥").font(.system(size: s * 0.16)).offset(x: -s * 0.33, y: -s * 0.36)
                Text("🔥").font(.system(size: s * 0.16)).offset(x: s * 0.33, y: -s * 0.36)
            }

            // Stubble along the jaw — "auburn," allegedly
            ForEach(0..<9, id: \.self) { i in
                let angle = Double.pi * (0.30 + 0.40 * Double(i) / 8.0)
                Circle()
                    .fill(stubble)
                    .frame(width: s * 0.035, height: s * 0.035)
                    .offset(x: s * 0.40 * CGFloat(cos(angle)),
                            y: s * 0.40 * CGFloat(sin(angle)))
            }

            eye(offsetX: -s * 0.17, s: s)
            eye(offsetX: s * 0.17, s: s)

            brow(s: s, left: true)
            brow(s: s, left: false)

            mouth(s: s)

            if mood == .raging {
                Text("💢").font(.system(size: s * 0.20)).offset(x: s * 0.40, y: -s * 0.42)
            }

            // Dino egg necklace
            Text("🥚🥚🥚").font(.system(size: s * 0.15)).offset(y: s * 0.50)
        }
        .frame(width: s, height: s * 1.12)
    }

    private func eye(offsetX: CGFloat, s: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .overlay(Ellipse().stroke(.black, lineWidth: s * 0.012))
                .frame(width: s * 0.17, height: mood == .raging ? s * 0.11 : s * 0.16)
            Circle()
                .fill(.black)
                .frame(width: s * 0.05, height: s * 0.05)
                .offset(y: mood == .defeated ? s * 0.02 : 0)
        }
        .offset(x: offsetX, y: -s * 0.08)
    }

    private func brow(s: CGFloat, left: Bool) -> some View {
        let angry = mood != .defeated
        let tilt: Double = angry ? (mood == .raging ? 30 : 24) : -14
        return Capsule()
            .fill(.black)
            .frame(width: s * 0.26, height: s * 0.05)
            .rotationEffect(.degrees(left ? tilt : -tilt))
            .offset(x: left ? -s * 0.17 : s * 0.17,
                    y: angry ? -s * 0.24 : -s * 0.28)
    }

    @ViewBuilder
    private func mouth(s: CGFloat) -> some View {
        if mood == .defeated {
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(.black, style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                .frame(width: s * 0.30, height: s * 0.30)
                .offset(y: s * 0.36)
        } else {
            // The signature move: gritted-teeth grin. Furious AND delighted.
            RoundedRectangle(cornerRadius: s * 0.05)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: s * 0.05).stroke(.black, lineWidth: s * 0.018))
                .overlay(
                    HStack(spacing: s * 0.085) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle().fill(.black).frame(width: s * 0.012)
                        }
                    }
                )
                .overlay(Rectangle().fill(.black).frame(height: s * 0.012))
                .frame(width: s * 0.42, height: s * 0.15)
                .offset(y: s * 0.24)
        }
    }
}
