import AppKit
import AVFoundation
import Foundation

@MainActor
protocol SoundPlaying: AnyObject {
    func play(sound: AlertSoundOption, repeating: Bool)
    func stop()
}

@MainActor
final class SystemSoundPlayer: SoundPlaying {
    private var repeatTimer: Timer?
    private var currentSystemSound: NSSound?
    private var currentAudioPlayer: AVAudioPlayer?
    private var cachedWaveData: [AlertSoundOption: Data] = [:]

    func play(sound: AlertSoundOption, repeating: Bool) {
        stop()

        guard sound != .none else { return }
        playOnce(sound: sound)

        if repeating {
            let interval: TimeInterval = (sound == .criticalAlarm || sound == .radarPulse) ? 1.6 : 2.2
            repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.playOnce(sound: sound)
                }
            }
        }
    }

    func stop() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        currentSystemSound?.stop()
        currentSystemSound = nil
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
    }

    private func playOnce(sound: AlertSoundOption) {
        if sound.isCustomSynthesized {
            let data = cachedWaveData[sound] ?? SynthesizedSoundGenerator.waveData(for: sound)
            if let data {
                cachedWaveData[sound] = data
                do {
                    let player = try AVAudioPlayer(data: data)
                    player.prepareToPlay()
                    player.play()
                    currentAudioPlayer = player
                    return
                } catch {
                    NSSound.beep()
                }
            }
        } else if let name = sound.systemSoundName,
                  let sysSound = NSSound(named: NSSound.Name(name)) {
            currentSystemSound?.stop()
            currentSystemSound = sysSound
            sysSound.play()
        } else {
            NSSound.beep()
        }
    }
}

enum SynthesizedSoundGenerator {
    private struct ToneSegment {
        let startTime: Double
        let duration: Double
        let frequency: Double
        let endFrequency: Double?
        let amplitude: Double
        let harmonicMix: Double
    }

    static func waveData(for option: AlertSoundOption) -> Data? {
        guard option.isCustomSynthesized else { return nil }
        let segments: [ToneSegment]
        let totalDuration: Double

        switch option {
        case .criticalAlarm:
            // Urgent triple high-attention two-tone alarm pulse
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.14, frequency: 880, endFrequency: 1046.5, amplitude: 0.45, harmonicMix: 0.30),
                ToneSegment(startTime: 0.17, duration: 0.14, frequency: 1046.5, endFrequency: 1318.5, amplitude: 0.48, harmonicMix: 0.30),
                ToneSegment(startTime: 0.36, duration: 0.14, frequency: 880, endFrequency: 1046.5, amplitude: 0.45, harmonicMix: 0.30),
                ToneSegment(startTime: 0.53, duration: 0.22, frequency: 1046.5, endFrequency: 1318.5, amplitude: 0.50, harmonicMix: 0.32)
            ]
            totalDuration = 0.80

        case .urgentBeep:
            // Crisp double attention beep
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.14, frequency: 784.0, endFrequency: nil, amplitude: 0.42, harmonicMix: 0.25),
                ToneSegment(startTime: 0.20, duration: 0.18, frequency: 987.8, endFrequency: nil, amplitude: 0.44, harmonicMix: 0.25)
            ]
            totalDuration = 0.45

        case .lowWarning:
            // Descending two-note warning (signals draining battery)
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.18, frequency: 659.25, endFrequency: nil, amplitude: 0.36, harmonicMix: 0.18),
                ToneSegment(startTime: 0.18, duration: 0.32, frequency: 493.88, endFrequency: nil, amplitude: 0.34, harmonicMix: 0.15)
            ]
            totalDuration = 0.55

        case .chargedChime:
            // Bright ascending major arpeggio (C5 - E5 - G5 - C6)
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.22, frequency: 523.25, endFrequency: nil, amplitude: 0.28, harmonicMix: 0.22),
                ToneSegment(startTime: 0.10, duration: 0.24, frequency: 659.25, endFrequency: nil, amplitude: 0.28, harmonicMix: 0.22),
                ToneSegment(startTime: 0.20, duration: 0.28, frequency: 783.99, endFrequency: nil, amplitude: 0.30, harmonicMix: 0.22),
                ToneSegment(startTime: 0.30, duration: 0.50, frequency: 1046.50, endFrequency: nil, amplitude: 0.32, harmonicMix: 0.24)
            ]
            totalDuration = 0.85

        case .powerConnect:
            // Crisp ascending two-tone power chime (A4 -> E5)
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.18, frequency: 440.0, endFrequency: nil, amplitude: 0.32, harmonicMix: 0.20),
                ToneSegment(startTime: 0.11, duration: 0.40, frequency: 659.25, endFrequency: nil, amplitude: 0.36, harmonicMix: 0.24)
            ]
            totalDuration = 0.56

        case .powerDisconnect:
            // Soft descending two-note disconnect cue (C5 -> G4)
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.14, frequency: 523.25, endFrequency: nil, amplitude: 0.28, harmonicMix: 0.14),
                ToneSegment(startTime: 0.12, duration: 0.26, frequency: 392.00, endFrequency: nil, amplitude: 0.26, harmonicMix: 0.12)
            ]
            totalDuration = 0.42

        case .radarPulse:
            // Clean sonar/radar pulse
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.45, frequency: 987.77, endFrequency: nil, amplitude: 0.38, harmonicMix: 0.28)
            ]
            totalDuration = 0.50

        case .softBell:
            // Pure gentle harmonic bell
            segments = [
                ToneSegment(startTime: 0.00, duration: 0.65, frequency: 880.0, endFrequency: nil, amplitude: 0.32, harmonicMix: 0.26)
            ]
            totalDuration = 0.70

        default:
            return nil
        }

        return renderWAV(segments: segments, totalDuration: totalDuration)
    }

    private static func renderWAV(segments: [ToneSegment], totalDuration: Double) -> Data {
        let sampleRate = 44_100
        let sampleCount = max(1, Int(totalDuration * Double(sampleRate)))
        var pcmSamples = [Int16](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            var mixedSample = 0.0

            for seg in segments {
                let localT = t - seg.startTime
                guard localT >= 0 && localT <= seg.duration else { continue }

                let progress = localT / seg.duration
                let attack = min(1.0, localT / 0.012)
                let decay = pow(max(0.0, 1.0 - progress), 1.45)
                let envelope = attack * decay

                let freq: Double
                if let endFreq = seg.endFrequency {
                    freq = seg.frequency + (endFreq - seg.frequency) * progress
                } else {
                    freq = seg.frequency
                }

                let fundamental = sin(2.0 * .pi * freq * localT)
                let overtone = sin(2.0 * .pi * (freq * 2.0) * localT) * seg.harmonicMix
                let thirdOvertone = sin(2.0 * .pi * (freq * 3.0) * localT) * (seg.harmonicMix * 0.35)
                mixedSample += (fundamental + overtone + thirdOvertone) * seg.amplitude * envelope
            }

            let clamped = max(-0.95, min(0.95, mixedSample))
            pcmSamples[i] = Int16(clamped * Double(Int16.max))
        }

        let dataByteCount = UInt32(pcmSamples.count * MemoryLayout<Int16>.size)
        let riffChunkSize = UInt32(36) + dataByteCount
        var data = Data()
        data.reserveCapacity(44 + Int(dataByteCount))

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendLE(riffChunkSize, to: &data)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        appendLE(UInt32(16), to: &data)                   // PCM subchunk size
        appendLE(UInt16(1), to: &data)                    // PCM format
        appendLE(UInt16(1), to: &data)                    // Mono
        appendLE(UInt32(sampleRate), to: &data)
        appendLE(UInt32(sampleRate * 2), to: &data)       // Byte rate
        appendLE(UInt16(2), to: &data)                    // Block align
        appendLE(UInt16(16), to: &data)                   // Bits per sample
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendLE(dataByteCount, to: &data)

        pcmSamples.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                data.append(UnsafeBufferPointer(start: UnsafeRawPointer(base).assumingMemoryBound(to: UInt8.self), count: Int(dataByteCount)))
            }
        }

        return data
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }
}
