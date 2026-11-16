import AppKit
import Foundation

@MainActor
protocol SoundPlaying: AnyObject {
    func play(sound: AlertSoundOption, repeating: Bool)
    func stop()
}

@MainActor
final class SystemSoundPlayer: SoundPlaying {
    private var repeatTimer: Timer?
    private var currentSound: NSSound?

    func play(sound: AlertSoundOption, repeating: Bool) {
        stop()

        guard let name = sound.systemSoundName else { return }
        playOnce(named: name)

        if repeating {
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.playOnce(named: name)
                }
            }
        }
    }

    func stop() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        currentSound?.stop()
        currentSound = nil
    }

    private func playOnce(named name: String) {
        if let sysSound = NSSound(named: NSSound.Name(name)) {
            currentSound?.stop()
            currentSound = sysSound
            sysSound.play()
        } else {
            NSSound.beep()
        }
    }
}
