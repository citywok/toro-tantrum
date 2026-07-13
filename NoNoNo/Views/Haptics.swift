import UIKit

enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationError = UINotificationFeedbackGenerator()
    private static let notificationSuccess = UINotificationFeedbackGenerator()

    static func hit() {
        impact.impactOccurred()
    }

    static func bad() {
        notificationError.notificationOccurred(.error)
    }

    static func rage() {
        notificationSuccess.notificationOccurred(.success)
    }
}
