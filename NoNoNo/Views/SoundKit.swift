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

/// Dynamic music intensity levels.
enum MusicIntensity { case normal, intense, rage }

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

    // MARK: - Background Music

    private var musicPlayer: AVAudioPlayerNode?
    private(set) var musicPlaying = false
    private var currentIntensity: MusicIntensity = .normal
    private var normalBuffer: AVAudioPCMBuffer?
    private var intenseBuffer: AVAudioPCMBuffer?
    private var rageBuffer: AVAudioPCMBuffer?

    /// Start looping 8-bit chiptune background music.
    /// Respects any intensity that was set before music started.
    func startMusic() {
        guard !musicPlaying else { return }
        startIfNeeded()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        musicPlayer = player

        let bpm: Double
        switch currentIntensity {
        case .normal:   bpm = 140
        case .intense:  bpm = 165
        case .rage:     bpm = 190
        }
        let buffer = makeMusicBuffer(bpm: bpm, duration: 8.0)
        // Cache the generated buffer
        switch currentIntensity {
        case .normal:   normalBuffer = buffer
        case .intense:  intenseBuffer = buffer
        case .rage:     rageBuffer = buffer
        }
        player.volume = 0.4  // background music sits underneath sound effects
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        musicPlaying = true
    }

    /// Stop background music.
    func stopMusic() {
        guard let player = musicPlayer, musicPlaying else { return }
        player.stop()
        engine.detach(player)
        musicPlayer = nil
        musicPlaying = false
    }

    /// Swap to a different music intensity. Generates buffers lazily.
    func setMusicIntensity(_ intensity: MusicIntensity) {
        guard intensity != currentIntensity, let player = musicPlayer, musicPlaying else {
            currentIntensity = intensity
            return
        }
        currentIntensity = intensity

        let buffer: AVAudioPCMBuffer
        switch intensity {
        case .normal:
            if let cached = normalBuffer { buffer = cached }
            else { buffer = makeMusicBuffer(bpm: 140, duration: 8.0); normalBuffer = buffer }
        case .intense:
            if let cached = intenseBuffer { buffer = cached }
            else { buffer = makeMusicBuffer(bpm: 165, duration: 8.0); intenseBuffer = buffer }
        case .rage:
            if let cached = rageBuffer { buffer = cached }
            else { buffer = makeMusicBuffer(bpm: 190, duration: 8.0); rageBuffer = buffer }
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    // MARK: - 8-bit Chiptune Generator

    private func makeMusicBuffer(bpm: Double, duration: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]

        let beatsPerSecond = bpm / 60.0
        // ── note helpers ──
        func sq(_ t: Double, _ freq: Double) -> Double {
            (t * freq).truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : -1.0
        }
        func freq(_ midi: Int) -> Double { 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0) }

        // ── note sequences ──
        // Each note: (startBeat, durationBeats, midiNote)
        // Melody — 8 bars of arpeggiated 8-bit flavour
        let melody: [(Double, Double, Int)] = [
            // Bar 0-1: C-E-G-C up, B-G-E-C down
            (0, 0.25, 60), (0.25, 0.25, 64), (0.5, 0.25, 67), (0.75, 0.25, 72),
            (1, 0.25, 71), (1.25, 0.25, 67), (1.5, 0.25, 64), (1.75, 0.25, 60),
            // Bar 2-3: G-B-D-G up, E-D-B-G down
            (2, 0.25, 67), (2.25, 0.25, 71), (2.5, 0.25, 74), (2.75, 0.25, 79),
            (3, 0.25, 76), (3.25, 0.25, 74), (3.5, 0.25, 71), (3.75, 0.25, 67),
            // Bar 4-5: A-C-E-A up, G-E-C-A down
            (4, 0.25, 69), (4.25, 0.25, 72), (4.5, 0.25, 76), (4.75, 0.25, 81),
            (5, 0.25, 79), (5.25, 0.25, 76), (5.5, 0.25, 72), (5.75, 0.25, 69),
            // Bar 6-7: F-A-C-F up, E-C-A-F → to G-C-E-G for the turn
            (6, 0.25, 65), (6.25, 0.25, 69), (6.5, 0.25, 72), (6.75, 0.25, 77),
            (7, 0.25, 76), (7.25, 0.25, 72), (7.5, 0.25, 69), (7.75, 0.5, 67),
        ]

        // Bass — dark power chords on the downbeats
        let bass: [(Double, Double, Int)] = [
            (0, 2, 48), (2, 2, 55),
            (4, 2, 45), (6, 2, 52),
        ]

        // Harmony — long chord stabs every 2 beats
        let harmony: [(Double, Double, Int)] = [
            (0, 2, 67), (2, 2, 71),
            (4, 2, 64), (6, 2, 69),
        ]

        let totalBeats = 8.0

        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let beat = (t * beatsPerSecond).truncatingRemainder(dividingBy: totalBeats)

            var sample: Double = 0

            // ── melody voice ──
            for note in melody {
                let end = note.0 + note.1
                if beat >= note.0 && beat < end {
                    let local = (beat - note.0)
                    let env = min(local * 40, 1.0) * min((end - beat) * 80, 1.0)
                    sample += sq(t, freq(note.2)) * 0.10 * env
                    break
                }
            }

            // ── bass voice ──
            for note in bass {
                let end = note.0 + note.1
                if beat >= note.0 && beat < end {
                    let local = (beat - note.0)
                    let env = min(local * 20, 1.0) * min((end - beat) * 40, 1.0)
                    sample += sq(t, freq(note.2)) * 0.12 * env
                    break
                }
            }

            // ── harmony voice (pulse with a different duty for texture) ──
            for note in harmony {
                let end = note.0 + note.1
                if beat >= note.0 && beat < end {
                    let local = (beat - note.0)
                    let env = min(local * 10, 1.0) * min((end - beat) * 20, 1.0)
                    let phase = (t * freq(note.2)).truncatingRemainder(dividingBy: 1.0)
                    let pulse: Double = phase < 0.25 ? 1.0 : -1.0  // 25% duty = thinner
                    sample += pulse * 0.06 * env
                    break
                }
            }

            // Soft clip to [-0.7, 0.7] to avoid harsh digital clipping
            data[i] = Float(max(-0.7, min(0.7, sample)))
        }

        return buffer
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
