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
        speak("nooo!")
    }

    /// Letting one get away. Note the cadence: one no, a beat, then the flood.
    func sayNoNoNoNoNo() {
        speak("noo, no no no no!")
    }

    func sayRage() {
        speak("toro! tantrum!")
    }

    func sayGameOver() {
        speak("toro tantrum. nooo.", rate: 0.38)
    }

    /// Called when a good combo milestone is hit — the raging chant.
    func sayToro() {
        speak("toro tantrum!", rate: 0.48)
    }

    /// Spoken on the start screen.
    func sayJeMapelle() {
        speak("i love toro", rate: 0.48)
    }

    /// Spoken when the game begins.
    func sayIntro() {
        speak("toro tantrum!", rate: 0.48)
    }

    func speak(_ text: String, rate: Float = 0.58, language: String = "en-US") {
        GameAudioSession.configure()
        // A new outburst interrupts the previous one immediately.
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        utterance.pitchMultiplier = 0.85
        synthesizer.speak(utterance)
    }
}
