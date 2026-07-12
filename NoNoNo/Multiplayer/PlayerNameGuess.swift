import UIKit

/// Best-effort guess at the player's first name so nobody has to type —
/// but the field stays editable, because "HOT LAVA" is a valid identity.
enum PlayerNameGuess {
    /// Parse a first name out of a device name like "Josh's iPhone".
    /// Returns nil for the generic names modern iOS hands out.
    static func firstName(fromDeviceName device: String) -> String? {
        let trimmed = device.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        guard !trimmed.isEmpty, lower != "iphone", lower != "ipad" else { return nil }

        for possessive in ["'s ", "\u{2019}s "] {
            if let range = trimmed.range(of: possessive) {
                let name = String(trimmed[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        // A custom device name with no possessive ("Mothership") is still
        // more fun than PLAYER 1.
        if !lower.contains("iphone") && !lower.contains("ipad") {
            return trimmed
        }
        return nil
    }

    static func fromDevice() -> String? {
        firstName(fromDeviceName: UIDevice.current.name)
    }
}
