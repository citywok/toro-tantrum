import SwiftUI

/// Every Josh we have, grouped by state of mind. Faces rotate so a fresh
/// Josh shows up round to round.
enum FacePool {
    static let grinning = ["face_angry", "face_grin", "face_drag", "face_squint", "face_mullet"]
    static let raging = ["face_smashed", "face_party", "face_fancy", "face_wine"]
    static let defeated = ["face_ko", "face_angel"]

    static func pool(for mood: FaceView.Mood) -> [String] {
        switch mood {
        case .grinning: return grinning
        case .raging: return raging
        case .defeated: return defeated
        }
    }

    static func random(for mood: FaceView.Mood) -> String {
        pool(for: mood).randomElement() ?? "face_angry"
    }
}

/// The real Josh, South Park Canadian style: an actual photo cutout whose
/// top half flaps open when he yells, Terrance & Phillip physics.
struct PhotoFaceView: View {
    var mood: FaceView.Mood = .grinning
    var ginger: Bool = false
    var size: CGFloat = 160
    var talking: Bool = false

    @State private var flapUp = false
    @State private var chosenFace: String?

    /// Where the head splits, as a fraction of height from the top.
    private let splitFraction: CGFloat = 0.60

    private var imageName: String {
        chosenFace ?? FacePool.pool(for: mood).first ?? "face_angry"
    }

    var body: some View {
        let s = size
        ZStack {
            // Mouth interior, revealed when the head flaps open.
            Ellipse()
                .fill(Color(red: 0.25, green: 0.05, blue: 0.05))
                .frame(width: s * 0.52, height: s * 0.36)
                .offset(y: s * 0.16)

            headHalf(top: false, s: s)
            // The whole top half lifts straight up with a slight tilt —
            // Terrance & Phillip style, not a hinge.
            headHalf(top: true, s: s)
                .rotationEffect(.degrees(flapUp ? -6 : 0),
                                anchor: UnitPoint(x: 0.5, y: splitFraction))
                .offset(y: flapUp ? -s * 0.11 : 0)

            if ginger {
                Text("🔥").font(.system(size: s * 0.20)).offset(x: -s * 0.38, y: -s * 0.44)
                Text("🔥").font(.system(size: s * 0.20)).offset(x: s * 0.38, y: -s * 0.44)
            }
            if mood == .raging {
                Text("🍣").font(.system(size: s * 0.26)).offset(x: s * 0.44, y: -s * 0.36)
            }

            Text("🥚🥚🥚").font(.system(size: s * 0.15)).offset(y: s * 0.50)
        }
        .frame(width: s, height: s * 1.06)
        .onAppear { chosenFace = FacePool.random(for: mood) }
        .onChange(of: mood) { newMood in
            chosenFace = FacePool.random(for: newMood)
        }
        .onChange(of: talking) { isTalking in
            if isTalking {
                withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
                    flapUp = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.11)) { flapUp = false }
            }
        }
    }

    private func headHalf(top: Bool, s: CGFloat) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: s, height: s)
            .clipShape(RoundedRectangle(cornerRadius: s * 0.24))
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.24)
                    .stroke(.black, lineWidth: s * 0.022)
            )
            .mask(
                Rectangle()
                    .frame(width: s, height: top ? s * splitFraction : s * (1 - splitFraction))
                    .frame(width: s, height: s, alignment: top ? .top : .bottom)
            )
    }
}

/// Chooses between the real Josh and the construction-paper Josh.
struct CharacterFace: View {
    var mood: FaceView.Mood = .grinning
    var ginger: Bool = false
    var size: CGFloat = 160
    var talking: Bool = false

    @AppStorage("cartoonMode") private var cartoonMode = false

    var body: some View {
        if cartoonMode {
            FaceView(mood: mood, ginger: ginger, size: size)
        } else {
            PhotoFaceView(mood: mood, ginger: ginger, size: size, talking: talking)
        }
    }
}
