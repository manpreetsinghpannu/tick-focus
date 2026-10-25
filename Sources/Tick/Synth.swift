import AVFoundation

/// Generates every sound in code (no audio files): tick styles, the start chime and the end bell.
/// Each voice is an oscillator or filtered noise burst with a fast attack and exponential decay.
enum Synth {
    static let sampleRate = 44_100.0
    static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    enum Wave { case sine, triangle, square }
    enum Filter { case bandpass, highpass }

    final class Canvas {
        var samples: [Float]

        init(duration: Double) {
            samples = Array(repeating: 0, count: Int(duration * Synth.sampleRate))
        }

        func osc(at start: Double = 0, _ wave: Wave, _ f0: Double, sweepTo f1: Double? = nil,
                 peak: Double, decay: Double) {
            let first = Int(start * sampleRate)
            let count = Int((decay + 0.03) * sampleRate)
            var phase = 0.0
            for i in 0..<count {
                let index = first + i
                guard index < samples.count else { break }
                let t = Double(i) / sampleRate
                let freq = f1.map { f0 * pow($0 / f0, min(t, decay) / decay) } ?? f0
                phase += 2 * .pi * freq / sampleRate
                let value: Double = switch wave {
                case .sine: sin(phase)
                case .square: sin(phase) >= 0 ? 1 : -1
                case .triangle: 2 / .pi * asin(sin(phase))
                }
                samples[index] += Float(value * Synth.envelope(t, peak: peak, decay: decay))
            }
        }

        func noise(at start: Double = 0, _ filter: Filter, _ freq: Double, q: Double,
                   peak: Double, decay: Double) {
            // RBJ biquad, same shapes as the Web Audio filters used in the preview mockup.
            let w0 = 2 * .pi * freq / sampleRate
            let alpha = sin(w0) / (2 * q)
            let cw = cos(w0)
            var (b0, b1, b2): (Double, Double, Double) = switch filter {
            case .bandpass: (alpha, 0, -alpha)
            case .highpass: ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2)
            }
            let a0 = 1 + alpha
            let a1 = -2 * cw / a0, a2 = (1 - alpha) / a0
            b0 /= a0; b1 /= a0; b2 /= a0

            var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            let first = Int(start * sampleRate)
            let count = Int((decay + 0.03) * sampleRate)
            for i in 0..<count {
                let index = first + i
                guard index < samples.count else { break }
                let x = Double.random(in: -1...1)
                let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                x2 = x1; x1 = x; y2 = y1; y1 = y
                let t = Double(i) / sampleRate
                samples[index] += Float(y * Synth.envelope(t, peak: peak, decay: decay))
            }
        }

        func buffer() -> AVAudioPCMBuffer {
            let buf = AVAudioPCMBuffer(pcmFormat: Synth.format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = buf.frameCapacity
            let out = buf.floatChannelData![0]
            for i in samples.indices { out[i] = max(-1, min(1, samples[i])) }
            return buf
        }
    }

    static func envelope(_ t: Double, peak: Double, decay: Double) -> Double {
        let attack = 0.002, floor = 0.0001
        if t < attack { return floor * pow(peak / floor, t / attack) }
        if t >= decay { return 0 }
        return peak * pow(floor / peak, (t - attack) / (decay - attack))
    }

    private static func render(_ duration: Double, _ draw: (Canvas) -> Void) -> AVAudioPCMBuffer {
        let canvas = Canvas(duration: duration)
        draw(canvas)
        return canvas.buffer()
    }

    /// `accent` is the "tock" for the mechanical clock and the downbeat for the metronome.
    static func tick(_ sound: TickSound, accent: Bool) -> AVAudioPCMBuffer {
        switch sound {
        case .mechanical:
            let f = accent ? 2500.0 : 3500.0
            return render(0.08) {
                $0.noise(.bandpass, f, q: 6, peak: 1, decay: 0.035)
                $0.osc(.sine, f * 0.6, peak: 0.12, decay: 0.02)
            }
        case .softClick:
            return render(0.05) { $0.noise(.highpass, 2600, q: 0.707, peak: 0.35, decay: 0.012) }
        case .metronome:
            return render(0.1) {
                $0.osc(.sine, accent ? 1750 : 1250, peak: 0.55, decay: 0.06)
                $0.noise(.highpass, 5000, q: 0.707, peak: 0.2, decay: 0.008)
            }
        case .waterDrop:
            return render(0.11) { $0.osc(.sine, 480, sweepTo: 1350, peak: 0.5, decay: 0.07) }
        case .digitalBeep:
            return render(0.08) { $0.osc(.square, 2100, peak: 0.07, decay: 0.045) }
        }
    }

    /// Two gentle rising notes (C6 then G6).
    static func chime() -> AVAudioPCMBuffer {
        render(1.15) { c in
            for (freq, delay) in [(1046.5, 0.0), (1568.0, 0.16)] {
                c.osc(at: delay, .sine, freq, peak: 0.35, decay: 0.9)
                c.osc(at: delay, .sine, freq * 2, peak: 0.06, decay: 0.5)
            }
        }
    }

    /// Three bell strikes with inharmonic partials.
    static func bell() -> AVAudioPCMBuffer {
        render(2.6) { c in
            for start in [0.0, 0.55, 1.1] {
                c.osc(at: start, .sine, 880, peak: 0.4, decay: 1.4)
                c.osc(at: start, .sine, 880 * 2.76, peak: 0.12, decay: 0.7)
                c.osc(at: start, .sine, 880 * 5.4, peak: 0.05, decay: 0.35)
            }
        }
    }
}
