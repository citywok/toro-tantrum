import AVFoundation

/// He says it out loud. Text-to-speech, pitched down to maximum grump.
final class VoiceBox {
    static let shared = VoiceBox()

    private let synthesizer = AVSpeechSynthesizer()

    /// Short bark for every proper smack.
    func sayNo() {
        speak("no!", rate: 0.5)
    }

    /// Touching something he loves.
    func sayGoddamnit() {
        speak("god damn it!")
    }

    /// Letting one get away. Note the cadence: one no, a beat, then the flood.
    func sayNoNoNoNoNo() {
        speak("no, no no no no!")
    }

    func sayRage() {
        speak("Josh! Smashed!")
    }

    func sayGameOver() {
        speak("game over. god damn it.")
    }

    func speak(_ text: String, rate: Float = 0.58) {
        GameAudioSession.configure()
        // A new outburst interrupts the previous one immediately.
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 0.85
        synthesizer.speak(utterance)
    }
}
