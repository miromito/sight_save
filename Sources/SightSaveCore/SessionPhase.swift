import Foundation

/// High-level phase of the sit/break session.
public enum SessionPhase: Equatable, Sendable {
    /// No active work session; user is away or just started the app.
    case inactive
    /// Present, but has not yet been present continuously for X minutes.
    case settling
    /// Work timer is running (below Y).
    case working
    /// Work limit reached; overtime is counting.
    case overtime
    /// Away longer than X after work started; rest timer counting toward Z.
    case resting
    /// User paused the session manually.
    case paused
}

/// What the UI / app controller should present after a tick.
public enum SessionAlert: Equatable, Sendable {
    case none
    case breakWarning
    case silentBreakWarning
    case restComplete
    case longCallNudge
}

/// Immutable snapshot used by the menu bar and overlays.
public struct SessionSnapshot: Equatable, Sendable {
    public var phase: SessionPhase
    public var workElapsed: TimeInterval
    public var overtimeElapsed: TimeInterval
    public var restElapsed: TimeInterval
    public var presenceAccumulated: TimeInterval
    public var awayElapsed: TimeInterval
    public var isPresent: Bool
    public var isInCall: Bool
    public var isPaused: Bool
    public var warningVisible: Bool
    public var snoozeRemaining: TimeInterval?
    public var alert: SessionAlert
    public var statusText: String

    public static let initial = SessionSnapshot(
        phase: .inactive,
        workElapsed: 0,
        overtimeElapsed: 0,
        restElapsed: 0,
        presenceAccumulated: 0,
        awayElapsed: 0,
        isPresent: false,
        isInCall: false,
        isPaused: false,
        warningVisible: false,
        snoozeRemaining: nil,
        alert: .none,
        statusText: "Away"
    )
}

/// Inputs sampled once per engine tick.
public struct PresenceSample: Equatable, Sendable {
    public var isPresent: Bool
    public var isInCall: Bool
    public var isSystemUnavailable: Bool

    public init(isPresent: Bool, isInCall: Bool, isSystemUnavailable: Bool) {
        self.isPresent = isPresent
        self.isInCall = isInCall
        self.isSystemUnavailable = isSystemUnavailable
    }
}
