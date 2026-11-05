import Foundation

/// Pure session state machine. No camera, AppKit, or timers — only time deltas + presence samples.
public final class SessionEngine: @unchecked Sendable {
    private var settings: AppSettings
    private var phase: SessionPhase = .inactive
    private var workElapsed: TimeInterval = 0
    private var overtimeElapsed: TimeInterval = 0
    private var restElapsed: TimeInterval = 0
    private var presenceAccumulated: TimeInterval = 0
    private var awayElapsed: TimeInterval = 0
    private var callElapsed: TimeInterval = 0
    private var warningDelivered = false
    private var warningVisible = false
    private var snoozeUntil: TimeInterval?
    private var longCallNudgeDelivered = false
    private var pausedPhase: SessionPhase = .inactive
    private var lastTickAt: TimeInterval?
    private var lastInCall = false

    public init(settings: AppSettings = .default) {
        self.settings = settings
    }

    public func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
    }

    public var currentSettings: AppSettings { settings }

    // MARK: - Commands

    public func pause(at now: TimeInterval) {
        guard phase != .paused else { return }
        pausedPhase = phase
        phase = .paused
        snoozeUntil = nil
        warningVisible = false
        lastTickAt = now
    }

    public func resume(at now: TimeInterval) {
        guard phase == .paused else { return }
        phase = pausedPhase == .paused ? .inactive : pausedPhase
        lastTickAt = now
    }

    public func reset(at now: TimeInterval) {
        phase = .inactive
        workElapsed = 0
        overtimeElapsed = 0
        restElapsed = 0
        presenceAccumulated = 0
        awayElapsed = 0
        callElapsed = 0
        warningDelivered = false
        warningVisible = false
        snoozeUntil = nil
        longCallNudgeDelivered = false
        pausedPhase = .inactive
        lastTickAt = now
    }

    public func snooze(at now: TimeInterval) {
        snoozeUntil = now + settings.snoozeDuration
        warningVisible = false
    }

    public func dismissWarning() {
        warningVisible = false
    }

    // MARK: - Tick

    @discardableResult
    public func tick(at now: TimeInterval, sample: PresenceSample) -> SessionSnapshot {
        let delta = lastTickAt.map { max(0, now - $0) } ?? 0
        lastTickAt = now

        var alert: SessionAlert = .none

        if phase == .paused {
            return makeSnapshot(alert: alert, present: effectivePresent(sample), inCall: sample.isInCall, now: now)
        }

        // Sleep / lock: treat as away and do not advance work/rest timers.
        if sample.isSystemUnavailable {
            applyAway(delta: 0, accumulateAway: false, alert: &alert)
            lastInCall = sample.isInCall
            return makeSnapshot(alert: alert, present: false, inCall: sample.isInCall, now: now)
        }

        let present = effectivePresent(sample)

        if sample.isInCall {
            callElapsed += delta
            if settings.longCallNudgeEnabled,
               callElapsed >= settings.longCallNudge,
               !longCallNudgeDelivered {
                longCallNudgeDelivered = true
                if alert == .none { alert = .longCallNudge }
            }
        } else {
            if lastInCall && warningDelivered && workElapsed >= settings.workLimit {
                // Call ended at/past the work limit — surface the full warning immediately.
                warningVisible = settings.warningStyle == .overlay
                if alert == .none {
                    alert = .breakWarning
                }
            }
            callElapsed = 0
            longCallNudgeDelivered = false
        }

        if present {
            applyPresent(delta: delta, now: now, inCall: sample.isInCall, alert: &alert)
        } else {
            applyAway(delta: delta, accumulateAway: true, alert: &alert)
        }

        lastInCall = sample.isInCall
        return makeSnapshot(alert: alert, present: present, inCall: sample.isInCall, now: now)
    }

    // MARK: - Internals

    private func effectivePresent(_ sample: PresenceSample) -> Bool {
        sample.isPresent || sample.isInCall
    }

    private func applyPresent(
        delta: TimeInterval,
        now: TimeInterval,
        inCall: Bool,
        alert: inout SessionAlert
    ) {
        awayElapsed = 0

        switch phase {
        case .inactive, .settling:
            presenceAccumulated += delta
            if presenceAccumulated >= settings.presenceThreshold {
                phase = workElapsed > 0
                    ? (workElapsed >= settings.workLimit ? .overtime : .working)
                    : .working
                presenceAccumulated = settings.presenceThreshold
            } else {
                phase = .settling
            }

        case .resting:
            // Returned before Z completed — rest does not count; resume work.
            restElapsed = 0
            phase = workElapsed >= settings.workLimit ? .overtime : .working
            advanceWork(delta: delta, now: now, inCall: inCall, alert: &alert)

        case .working, .overtime:
            advanceWork(delta: delta, now: now, inCall: inCall, alert: &alert)

        case .paused:
            break
        }
    }

    private func advanceWork(
        delta: TimeInterval,
        now: TimeInterval,
        inCall: Bool,
        alert: inout SessionAlert
    ) {
        workElapsed += delta
        if workElapsed >= settings.workLimit {
            overtimeElapsed = workElapsed - settings.workLimit
            phase = .overtime

            let snoozing = snoozeUntil.map { now < $0 } ?? false
            if !warningDelivered {
                warningDelivered = true
                if !snoozing {
                    emitBreakWarning(inCall: inCall, alert: &alert)
                }
            }

            if let until = snoozeUntil, now >= until {
                snoozeUntil = nil
                emitBreakWarning(inCall: inCall, alert: &alert)
            }
        } else {
            phase = .working
            overtimeElapsed = 0
        }
    }

    private func emitBreakWarning(inCall: Bool, alert: inout SessionAlert) {
        let kind = breakAlert(inCall: inCall)
        switch kind {
        case .none:
            warningVisible = false
        case .silentBreakWarning:
            warningVisible = false
            if alert == .none { alert = kind }
        case .breakWarning:
            warningVisible = settings.warningStyle == .overlay
            if alert == .none { alert = kind }
        case .restComplete, .longCallNudge:
            break
        }
    }

    private func applyAway(delta: TimeInterval, accumulateAway: Bool, alert: inout SessionAlert) {
        presenceAccumulated = 0

        switch phase {
        case .inactive:
            break

        case .settling:
            phase = .inactive

        case .working, .overtime:
            if accumulateAway {
                awayElapsed += delta
            }
            if awayElapsed >= settings.presenceThreshold {
                phase = .resting
                restElapsed = 0
                warningVisible = false
                snoozeUntil = nil
            }

        case .resting:
            if accumulateAway {
                restElapsed += delta
            }
            if restElapsed >= settings.restDuration {
                workElapsed = 0
                overtimeElapsed = 0
                restElapsed = 0
                awayElapsed = 0
                warningDelivered = false
                warningVisible = false
                snoozeUntil = nil
                phase = .inactive
                if alert == .none {
                    alert = .restComplete
                }
            }

        case .paused:
            break
        }
    }

    private func breakAlert(inCall: Bool) -> SessionAlert {
        guard inCall else { return .breakWarning }
        switch settings.callBehavior {
        case .dontDisturb:
            return .none
        case .silentOnly:
            return .silentBreakWarning
        case .normal:
            return .breakWarning
        }
    }

    private func makeSnapshot(
        alert: SessionAlert,
        present: Bool,
        inCall: Bool,
        now: TimeInterval
    ) -> SessionSnapshot {
        let snoozeRemaining: TimeInterval? = {
            guard let until = snoozeUntil else { return nil }
            let left = until - now
            return left > 0 ? left : nil
        }()

        return SessionSnapshot(
            phase: phase,
            workElapsed: workElapsed,
            overtimeElapsed: overtimeElapsed,
            restElapsed: restElapsed,
            presenceAccumulated: presenceAccumulated,
            awayElapsed: awayElapsed,
            isPresent: present,
            isInCall: inCall,
            isPaused: phase == .paused,
            warningVisible: warningVisible && settings.warningStyle == .overlay,
            snoozeRemaining: snoozeRemaining,
            alert: alert,
            statusText: StatusTextFormatter.text(
                phase: phase,
                workElapsed: workElapsed,
                overtimeElapsed: overtimeElapsed,
                restElapsed: restElapsed,
                isPresent: present,
                isInCall: inCall
            )
        )
    }
}

public enum StatusTextFormatter {
    public static func text(
        phase: SessionPhase,
        workElapsed: TimeInterval,
        overtimeElapsed: TimeInterval,
        restElapsed: TimeInterval,
        isPresent: Bool,
        isInCall: Bool
    ) -> String {
        switch phase {
        case .inactive:
            return "Away"
        case .settling:
            return isInCall ? "Call" : "Settling"
        case .working:
            if !isPresent && !isInCall { return "Away" }
            let prefix = isInCall ? "Call" : "Work"
            return "\(prefix) \(formatClock(workElapsed))"
        case .overtime:
            if !isPresent && !isInCall { return "Away" }
            return "Over +\(formatClock(overtimeElapsed))"
        case .resting:
            return "Rest \(formatClock(restElapsed))"
        case .paused:
            return "Paused"
        }
    }

    public static func formatClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
