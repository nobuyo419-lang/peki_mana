// AudioManager.swift — AVAudioEngineで合成効果音(アセット不要)
import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioManager: ObservableObject {
    @Published var enabled: Bool = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private var format: AVAudioFormat
    private var bgmTimer: Timer?

    init() {
        self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                          options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
        } catch {
            print("Audio setup failed:", error)
        }
    }

    func toggle() { enabled.toggle() }

    enum SFX {
        case bark, happy, treat, ding, no, snore, splash
    }

    func play(_ sfx: SFX) {
        guard enabled else { return }
        switch sfx {
        case .bark:
            playTone(freqs: [320, 220], durations: [0.07, 0.10], type: .square, volume: 0.35)
        case .happy:
            playTone(freqs: [523, 659, 784], durations: [0.10, 0.10, 0.16], type: .sine, volume: 0.32)
        case .treat:
            playTone(freqs: [880, 1175], durations: [0.08, 0.12], type: .sine, volume: 0.30)
        case .ding:
            playTone(freqs: [1568, 1318], durations: [0.10, 0.18], type: .sine, volume: 0.26)
        case .no:
            playTone(freqs: [196, 165], durations: [0.10, 0.20], type: .triangle, volume: 0.30)
        case .snore:
            playTone(freqs: [110, 70], durations: [0.30, 0.30], type: .triangle, volume: 0.18)
        case .splash:
            playNoise(duration: 0.35, volume: 0.20)
        }
    }

    enum WaveType { case sine, square, triangle }

    private func playTone(freqs: [Double], durations: [Double], type: WaveType, volume: Float) {
        guard freqs.count == durations.count else { return }
        var totalFrames: Int = 0
        for d in durations { totalFrames += Int(d * sampleRate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let chan = buffer.floatChannelData?[0] else { return }
        var idx = 0
        for (f, d) in zip(freqs, durations) {
            let frames = Int(d * sampleRate)
            for i in 0..<frames {
                let phase = Double(i) / sampleRate
                let raw: Double
                switch type {
                case .sine:
                    raw = sin(2 * .pi * f * phase)
                case .square:
                    raw = sin(2 * .pi * f * phase) > 0 ? 1.0 : -1.0
                case .triangle:
                    let p = (f * phase).truncatingRemainder(dividingBy: 1.0)
                    raw = 4 * abs(p - 0.5) - 1
                }
                // attack-release envelope
                let env: Double
                let progress = Double(i) / Double(frames)
                if progress < 0.05 { env = progress / 0.05 }
                else if progress > 0.85 { env = (1.0 - progress) / 0.15 }
                else { env = 1.0 }
                chan[idx] = Float(raw * env) * volume
                idx += 1
            }
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func playNoise(duration: Double, volume: Float) {
        let frames = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        guard let chan = buffer.floatChannelData?[0] else { return }
        for i in 0..<frames {
            let progress = Double(i) / Double(frames)
            let env = progress < 0.05 ? progress/0.05 : (progress > 0.7 ? (1 - progress)/0.3 : 1.0)
            chan[i] = Float(Double.random(in: -1...1) * env) * volume
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
