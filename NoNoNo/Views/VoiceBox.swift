import AVFoundation

/// He says it out loud. Text-to-speech, pitched down to maximum grump.
final class VoiceBox {
    static let shared = VoiceBox()

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionConfigured = false

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func sayNo() {
        speak("no no no no no!")
    }

    func speak(_ text: String) {
        configureSessionIfNeeded()
        // A new mistake interrupts the previous outburst immediately.
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.58
        utterance.pitchMultiplier = 0.85
        synthesizer.speak(utterance)
    }
}
