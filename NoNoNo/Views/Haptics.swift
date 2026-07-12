import UIKit

enum Haptics {
    static func hit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func bad() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func rage() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
