import SwiftUI

/// Haptic + sound + voice for every life loss on an engine. Attached above
/// GameView so the final mistake still yells after the board disappears.
/// Shared between the solo flow and the Rage-Off flow.
struct MistakeFeedback: ViewModifier {
    @ObservedObject var engine: GameEngine
    var hapticsOn: Bool
    var soundOn: Bool
    var voiceOn: Bool

    func body(content: Content) -> some View {
        content.onChange(of: engine.lastLifeLoss) { event in
            guard let event else { return }
            if hapticsOn { Haptics.bad() }
            if soundOn {
                event.cause == .badTap ? SoundKit.shared.mistake() : SoundKit.shared.escape()
            }
            if voiceOn {
                event.cause == .badTap
                    ? VoiceBox.shared.sayGoddamnit()
                    : VoiceBox.shared.sayNoNoNoNoNo()
            }
        }
    }
}

extension View {
    func mistakeFeedback(engine: GameEngine, hapticsOn: Bool,
                         soundOn: Bool, voiceOn: Bool) -> some View {
        modifier(MistakeFeedback(engine: engine, hapticsOn: hapticsOn,
                                 soundOn: soundOn, voiceOn: voiceOn))
    }
}
