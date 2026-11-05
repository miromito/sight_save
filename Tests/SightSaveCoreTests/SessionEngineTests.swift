import XCTest
@testable import SightSaveCore

final class SessionEngineTests: XCTestCase {
    private var settings: AppSettings!
    private var engine: SessionEngine!

    override func setUp() {
        super.setUp()
        settings = AppSettings(
            presenceThresholdMinutes: 2,
            workLimitMinutes: 50,
            restMinutes: 5,
            checkIntervalSeconds: 5,
            detectionMode: .hybrid,
            warningStyle: .overlay,
            snoozeMinutes: 5,
            restDoneSoundName: "Glass",
            callBehavior: .silentOnly,
            longCallNudgeMinutes: 60,
            longCallNudgeEnabled: true,
            launchAtLogin: false
        )
        engine = SessionEngine(settings: settings)
    }

    private func present(_ now: TimeInterval) -> SessionSnapshot {
        engine.tick(
            at: now,
            sample: PresenceSample(isPresent: true, isInCall: false, isSystemUnavailable: false)
        )
    }

    private func away(_ now: TimeInterval) -> SessionSnapshot {
        engine.tick(
            at: now,
            sample: PresenceSample(isPresent: false, isInCall: false, isSystemUnavailable: false)
        )
    }

    private func call(_ now: TimeInterval) -> SessionSnapshot {
        engine.tick(
            at: now,
            sample: PresenceSample(isPresent: false, isInCall: true, isSystemUnavailable: false)
        )
    }

    private func locked(_ now: TimeInterval) -> SessionSnapshot {
        engine.tick(
            at: now,
            sample: PresenceSample(isPresent: true, isInCall: false, isSystemUnavailable: true)
        )
    }

    // MARK: - Settling / work start

    func testWorkStartsAfterPresenceThreshold() {
        _ = present(0)
        var snap = present(60)
        XCTAssertEqual(snap.phase, .settling)

        snap = present(120)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertEqual(snap.workElapsed, 0, accuracy: 0.01)
    }

    func testLeavingDuringSettlingResets() {
        _ = present(0)
        _ = present(60)
        var snap = away(90)
        XCTAssertEqual(snap.phase, .inactive)

        snap = present(100)
        XCTAssertEqual(snap.phase, .settling)
        // Presence restarts from this tick's delta (10s since the away sample).
        XCTAssertEqual(snap.presenceAccumulated, 10, accuracy: 0.01)
    }

    // MARK: - Work / overtime

    func testBreakWarningAtWorkLimit() {
        _ = present(0)
        _ = present(120)
        let workEnd = 120.0 + 50.0 * 60.0
        var snap = present(workEnd)
        XCTAssertEqual(snap.phase, .overtime)
        XCTAssertEqual(snap.alert, .breakWarning)
        XCTAssertTrue(snap.warningVisible)
        XCTAssertEqual(snap.overtimeElapsed, 0, accuracy: 0.01)

        snap = present(workEnd + 40)
        XCTAssertEqual(snap.overtimeElapsed, 40, accuracy: 0.01)
        XCTAssertTrue(snap.statusText.hasPrefix("Over +"))
    }

    func testSnoozeHidesWarningThenReturns() {
        _ = present(0)
        _ = present(120)
        let limit = 120.0 + 50.0 * 60.0
        _ = present(limit)
        engine.snooze(at: limit)
        var snap = present(limit + 1)
        XCTAssertFalse(snap.warningVisible)

        snap = present(limit + 5.0 * 60.0)
        XCTAssertEqual(snap.alert, .breakWarning)
        XCTAssertTrue(snap.warningVisible)
    }

    // MARK: - Rest

    func testShortAwayDoesNotStartRest() {
        _ = present(0)
        _ = present(120)
        let afterWork = 120.0 + 600.0
        _ = present(afterWork)
        var snap = away(afterWork + 60)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertEqual(snap.workElapsed, 600, accuracy: 0.01)

        snap = present(afterWork + 90)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertEqual(snap.workElapsed, 630, accuracy: 1.0)
    }

    func testRestStartsAfterAwayThresholdAndEarlyReturnResumesWork() {
        _ = present(0)
        _ = present(120)
        let afterWork = 120.0 + 600.0
        _ = present(afterWork)
        var snap = away(afterWork + 120)
        XCTAssertEqual(snap.phase, .resting)
        XCTAssertEqual(snap.workElapsed, 600, accuracy: 0.01)

        let duringRest = afterWork + 120.0 + 60.0
        _ = away(duringRest)
        snap = present(duringRest + 1)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertEqual(snap.workElapsed, 601, accuracy: 1.0)
        XCTAssertEqual(snap.restElapsed, 0, accuracy: 0.01)
    }

    func testCompletedRestResetsSessionAndAlerts() {
        _ = present(0)
        _ = present(120)
        let afterWork = 120.0 + 600.0
        _ = present(afterWork)
        let restStart = afterWork + 120.0
        _ = away(restStart)
        let restDone = restStart + 5.0 * 60.0
        let snap = away(restDone)
        XCTAssertEqual(snap.phase, .inactive)
        XCTAssertEqual(snap.workElapsed, 0, accuracy: 0.01)
        XCTAssertEqual(snap.alert, .restComplete)
    }

    // MARK: - Pause / reset

    func testPauseFreezesTimers() {
        _ = present(0)
        _ = present(120)
        _ = present(220)
        engine.pause(at: 220)
        var snap = present(520)
        XCTAssertEqual(snap.phase, .paused)
        XCTAssertEqual(snap.workElapsed, 100, accuracy: 0.01)

        engine.resume(at: 520)
        snap = present(620)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertEqual(snap.workElapsed, 200, accuracy: 0.01)
    }

    func testResetClearsEverything() {
        _ = present(0)
        _ = present(120)
        _ = present(120.0 + 50.0 * 60.0)
        engine.reset(at: 9999)
        let snap = away(10_000)
        XCTAssertEqual(snap.phase, .inactive)
        XCTAssertEqual(snap.workElapsed, 0, accuracy: 0.01)
        XCTAssertEqual(snap.overtimeElapsed, 0, accuracy: 0.01)
        XCTAssertFalse(snap.warningVisible)
    }

    // MARK: - Calls & sleep

    func testCallCountsAsPresentWithoutCamera() {
        _ = call(0)
        let snap = call(120)
        XCTAssertEqual(snap.phase, .working)
        XCTAssertTrue(snap.isInCall)
    }

    func testSilentOnlyDuringCall() {
        var s = settings!
        s.callBehavior = .silentOnly
        engine.updateSettings(s)

        _ = call(0)
        _ = call(120)
        let snap = call(120.0 + 50.0 * 60.0)
        XCTAssertEqual(snap.phase, .overtime)
        XCTAssertEqual(snap.alert, .silentBreakWarning)
        XCTAssertFalse(snap.warningVisible)
    }

    func testDontDisturbDuringCall() {
        var s = settings!
        s.callBehavior = .dontDisturb
        engine.updateSettings(s)

        _ = call(0)
        _ = call(120)
        let snap = call(120.0 + 50.0 * 60.0)
        XCTAssertEqual(snap.alert, .none)
        XCTAssertFalse(snap.warningVisible)
    }

    func testCallEndWithOvertimeShowsFullWarning() {
        var s = settings!
        s.callBehavior = .silentOnly
        engine.updateSettings(s)

        _ = call(0)
        _ = call(120)
        let limit = 120.0 + 50.0 * 60.0
        _ = call(limit)
        let snap = present(limit + 10)
        XCTAssertEqual(snap.alert, .breakWarning)
        XCTAssertTrue(snap.warningVisible)
    }

    func testLongCallNudge() {
        _ = call(0)
        _ = call(120)
        let snap = call(120.0 + 60.0 * 60.0)
        XCTAssertEqual(snap.alert, .longCallNudge)
    }

    func testSleepPausesTimersAndTreatsAsAway() {
        _ = present(0)
        _ = present(120)
        _ = present(220)
        let snap = locked(520)
        XCTAssertFalse(snap.isPresent)
        XCTAssertEqual(snap.workElapsed, 100, accuracy: 0.01)
    }

    // MARK: - Status text

    func testStatusTextFormats() {
        XCTAssertEqual(StatusTextFormatter.formatClock(32 * 60 + 10), "32:10")
        XCTAssertEqual(StatusTextFormatter.formatClock(7 * 60 + 40), "7:40")
        XCTAssertEqual(StatusTextFormatter.formatClock(3661), "1:01:01")
        let text = StatusTextFormatter.text(
            phase: .overtime,
            workElapsed: 3000,
            overtimeElapsed: 460,
            restElapsed: 0,
            isPresent: true,
            isInCall: false
        )
        XCTAssertEqual(text, "Over +7:40")
    }
}
