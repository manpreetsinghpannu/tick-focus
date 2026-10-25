import AVFoundation

/// Plays the synthesized buffers. Ticks and effects (chime, bell) use separate nodes so they can overlap.
/// The audio engine only runs while sounds are playing: a running engine counts as "audio playing"
/// to macOS and would stop the Mac from going to sleep on its own.
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let tickNode = AVAudioPlayerNode()
    private let effectNode = AVAudioPlayerNode()
    private var tickCache: [String: AVAudioPCMBuffer] = [:]
    private lazy var chime = Synth.chime()
    private lazy var bell = Synth.bell()
    private var configObserver: NSObjectProtocol?
    private var idleStop: DispatchWorkItem?
    /// Longer than the gap between ticks, so the engine stays up for a whole ticking session.
    private let idleDelay: TimeInterval = 3

    init() {
        engine.attach(tickNode)
        engine.attach(effectNode)
        engine.connect(tickNode, to: engine.mainMixerNode, format: Synth.format)
        engine.connect(effectNode, to: engine.mainMixerNode, format: Synth.format)
        effectNode.volume = 0.8
        engine.prepare()
        // Output device changes (headphones, AirPods) stop the engine; bring it back.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self, self.idleStop != nil else { return }
            self.startEngine()
        }
    }

    func playTick(_ sound: TickSound, accent: Bool, volume: Float) {
        let key = "\(sound.rawValue)-\(accent)"
        let buffer = tickCache[key] ?? Synth.tick(sound, accent: accent)
        tickCache[key] = buffer
        tickNode.volume = volume
        play(buffer, on: tickNode)
    }

    func playChime() { play(chime, on: effectNode) }
    func playBell() { play(bell, on: effectNode) }

    private func startEngine() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func play(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        startEngine()
        guard engine.isRunning else { return }
        node.scheduleBuffer(buffer, completionHandler: nil)
        if !node.isPlaying { node.play() }
        scheduleIdleStop(after: Double(buffer.frameLength) / Synth.sampleRate)
    }

    /// Stops the engine once nothing has played for a few seconds.
    private func scheduleIdleStop(after soundLength: TimeInterval) {
        idleStop?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.idleStop = nil
            self.tickNode.stop()
            self.effectNode.stop()
            self.engine.stop()
        }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + soundLength + idleDelay, execute: work)
    }
}
