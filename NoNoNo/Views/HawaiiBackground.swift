import SwiftUI

struct HawaiiBackground: View {
    var rageMode: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: rageMode
                    ? [Color(red: 0.55, green: 0.05, blue: 0.05),
                       Color(red: 0.95, green: 0.30, blue: 0.05)]
                    : [Color(red: 0.20, green: 0.50, blue: 0.20),
                       Color(red: 0.90, green: 0.65, blue: 0.30)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: rageMode)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text("🌭").font(.system(size: 64)).opacity(0.5)
                    Spacer()
                    Text("🦕").font(.system(size: 84)).opacity(0.5)
                }
                .padding(.horizontal, 2)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
