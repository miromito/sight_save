import CoreGraphics
import Foundation

/// Seconds since the last keyboard or mouse event in the current login session.
enum IdleTimeProvider {
    static func secondsSinceLastInput() -> TimeInterval {
        // RawValue.max ≈ “any input event” (keyboard/mouse), a common CGEventSource pattern.
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: CGEventType.RawValue.max)!
        )
    }

    static func isUserActive(within threshold: TimeInterval = 30) -> Bool {
        secondsSinceLastInput() < threshold
    }
}
