import AppKit
import Foundation

enum SoundPlayer {
    /// Common macOS system sounds found in `/System/Library/Sounds`.
    static let systemSoundNames: [String] = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink"
    ]

    static func play(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
            return
        }
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        NSSound(contentsOf: url, byReference: true)?.play()
    }
}
