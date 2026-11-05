import Foundation
import SightSaveCore

@MainActor
final class PresenceMonitor {
    private let camera = CameraPresenceDetector()
    private(set) var cameraDenied = false
    private(set) var fellBackToKeyboardMouse = false

    func prepare(mode: DetectionMode) async {
        guard mode != .keyboardMouse else { return }
        let ok = await camera.requestAccessIfNeeded()
        cameraDenied = !ok
        if !ok {
            fellBackToKeyboardMouse = true
        }
    }

    /// Resolve whether the user appears present for the current settings.
    func samplePresence(mode: DetectionMode) async -> (present: Bool, usedCamera: Bool) {
        let effectiveMode: DetectionMode
        if cameraDenied || fellBackToKeyboardMouse {
            effectiveMode = .keyboardMouse
        } else {
            effectiveMode = mode
        }

        switch effectiveMode {
        case .keyboardMouse:
            return (IdleTimeProvider.isUserActive(within: 60), false)

        case .camera:
            let face = await camera.detectFacePresent()
            if camera.isPermissionDenied {
                cameraDenied = true
                fellBackToKeyboardMouse = true
                return (IdleTimeProvider.isUserActive(within: 60), false)
            }
            return (face, true)

        case .hybrid:
            if IdleTimeProvider.isUserActive(within: 45) {
                return (true, false)
            }
            let face = await camera.detectFacePresent()
            if camera.isPermissionDenied {
                cameraDenied = true
                fellBackToKeyboardMouse = true
                return (IdleTimeProvider.isUserActive(within: 60), false)
            }
            return (face, true)
        }
    }
}
