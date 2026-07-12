import AVFoundation

enum GameAudioSession {
    private static var configured = false

    static func configure() {
        guard !configured else { return }
        configured = true
        // .playback so the yelling works even with the silent switch on —
        // the yelling is the entire point of the app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

/// Synthesized game sounds — no audio assets, just PCM math.
final class SoundKit {
    static let shared = SoundKit()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
    }

    /// Smack pop. Pitch climbs a semitone per combo step, capped at +14.
    func smack(combo: Int) {
        let freq = 440.0 * pow(2.0, Double(min(max(combo, 0), 14)) / 12.0)
        play(makeBuffer(duration: 0.12) { t in
            let env = exp(-t * 28)
            let wave = sin(2 * .pi * freq * t) + 0.4 * sin(4 * .pi * freq * t)
            return Float(0.32 * env * wave)
        })
    }

    /// Low angry buzz for touching something he loves.
    func mistake() {
        play(makeBuffer(duration: 0.32) { t in
            let f = 110.0 - 40.0 * t
            let sine = sin(2 * .pi * f * t)
            let square: Double = sine > 0 ? 1 : -1
            return Float(0.26 * exp(-t * 7) * (0.7 * square + 0.3 * sine))
        })
    }

    /// Soft whiff when a target escapes.
    func escape() {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        play(makeBuffer(duration: 0.18) { t in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = Double(Int64(bitPattern: seed) >> 40) / Double(1 << 23)
            return Float(0.20 * exp(-t * 18) * noise)
        })
    }

    /// Rising sweep into FULL RALPH MODE.
    func rageStart() {
        play(makeBuffer(duration: 0.4) { t in
            let phase = 2 * .pi * (280 * t + (900.0 / (2 * 0.4)) * t * t)
            return Float(0.30 * exp(-t * 3) * sin(phase))
        })
    }

    /// The descending womp of failure.
    func gameOver() {
        play(makeBuffer(duration: 0.6) { t in
            let phase = 2 * .pi * (440 * t - (330.0 / (2 * 0.6)) * t * t)
            return Float(0.30 * exp(-t * 4) * sin(phase))
        })
    }

    // MARK: - Plumbing

    private func startIfNeeded() {
        guard !started else { return }
        GameAudioSession.configure()
        do {
            try engine.start()
            started = true
            players.forEach { $0.play() }
        } catch {
            // No audio hardware (some CI simulators) — stay silent.
        }
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        startIfNeeded()
        guard started else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func makeBuffer(duration: Double, render: (Double) -> Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            data[i] = render(Double(i) / sampleRate)
        }
        return buffer
    }
}
