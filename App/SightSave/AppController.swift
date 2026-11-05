import AppKit
import Combine
import SightSaveCore
import SwiftUI

@MainActor
final class AppController: ObservableObject {
    let settingsStore: SettingsStore
    private let engine: SessionEngine
    private let presenceMonitor = PresenceMonitor()
    private let callDetector = CallDetector()
    private let sleepLockMonitor = SleepLockMonitor()
    private let notifications = NotificationManager()
    private let menuBar = MenuBarController()
    private let overlay = BreakOverlayController()

    private var checkTask: Task<Void, Never>?
    private var settingsWindow: NSWindow?
    private var lastSnapshot = SessionSnapshot.initial
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        self.engine = SessionEngine(settings: settingsStore.settings)
        wireMenu()
        wireOverlay()
        observeSettings()
    }

    func start() {
        Task {
            await notifications.configure()
            await presenceMonitor.prepare(mode: settingsStore.settings.detectionMode)
            if presenceMonitor.cameraDenied {
                notifyCameraFallback()
            }
            sleepLockMonitor.start()
            sleepLockMonitor.onChange = { [weak self] _ in
                self?.runCheck()
            }
            restartLoop()
            runCheck()
        }
    }

    func stop() {
        checkTask?.cancel()
        sleepLockMonitor.stop()
    }

    // MARK: - Wiring

    private func wireMenu() {
        menuBar.onPauseResume = { [weak self] in
            guard let self else { return }
            let now = Date().timeIntervalSinceReferenceDate
            if self.lastSnapshot.isPaused {
                self.engine.resume(at: now)
            } else {
                self.engine.pause(at: now)
            }
            self.runCheck()
        }
        menuBar.onReset = { [weak self] in
            guard let self else { return }
            self.engine.reset(at: Date().timeIntervalSinceReferenceDate)
            self.overlay.hide()
            self.runCheck()
        }
        menuBar.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        menuBar.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func wireOverlay() {
        overlay.onSnooze = { [weak self] in
            guard let self else { return }
            self.engine.snooze(at: Date().timeIntervalSinceReferenceDate)
            self.overlay.hide()
            self.runCheck()
        }
        overlay.onDismiss = { [weak self] in
            guard let self else { return }
            self.engine.dismissWarning()
            self.overlay.hide()
            self.runCheck()
        }
    }

    private func observeSettings() {
        settingsStore.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.engine.updateSettings(settings)
                self.restartLoop()
                Task {
                    await self.presenceMonitor.prepare(mode: settings.detectionMode)
                }
            }
            .store(in: &cancellables)
    }

    private func restartLoop() {
        checkTask?.cancel()
        let interval = max(2, settingsStore.settings.checkIntervalSeconds)
        checkTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runCheckAsync()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func runCheck() {
        Task { await runCheckAsync() }
    }

    private func runCheckAsync() async {
        let settings = settingsStore.settings
        let inCall = callDetector.isInCall()
        let unavailable = sleepLockMonitor.isUnavailable

        let presence: Bool
        if unavailable {
            presence = false
        } else if inCall {
            // Never open the camera while another app is using it.
            presence = true
        } else {
            let sample = await presenceMonitor.samplePresence(mode: settings.detectionMode)
            presence = sample.present
            if presenceMonitor.fellBackToKeyboardMouse && presenceMonitor.cameraDenied {
                // one-shot style notice is handled at start; keep quiet here
            }
        }

        let now = Date().timeIntervalSinceReferenceDate
        let snapshot = engine.tick(
            at: now,
            sample: PresenceSample(
                isPresent: presence,
                isInCall: inCall,
                isSystemUnavailable: unavailable
            )
        )
        lastSnapshot = snapshot
        menuBar.update(snapshot: snapshot, settings: settings)
        handleAlerts(snapshot)
        updateOverlay(snapshot)
    }

    private func handleAlerts(_ snapshot: SessionSnapshot) {
        switch snapshot.alert {
        case .none:
            break
        case .breakWarning:
            if settingsStore.settings.warningStyle == .notification || !snapshot.warningVisible {
                notifications.post(
                    title: "Time for a break",
                    body: "You've been sitting for \(StatusTextFormatter.formatClock(snapshot.workElapsed)). Stand up and rest your eyes.",
                    sound: true
                )
            }
        case .silentBreakWarning:
            notifications.post(
                title: "Break reminder (on a call)",
                body: "Work limit reached. SightSave will remind you again when the call ends if you're still overtime.",
                sound: false
            )
        case .restComplete:
            SoundPlayer.play(named: settingsStore.settings.restDoneSoundName)
            notifications.post(
                title: "Rest complete",
                body: "You've rested long enough. Welcome back when you're ready.",
                sound: false
            )
        case .longCallNudge:
            notifications.post(
                title: "Long call",
                body: "You've been on a call for a while. If you can, stand up or stretch.",
                sound: false
            )
        }
    }

    private func updateOverlay(_ snapshot: SessionSnapshot) {
        guard settingsStore.settings.warningStyle == .overlay else {
            overlay.hide()
            return
        }
        if snapshot.warningVisible {
            overlay.show(
                overtimeText: StatusTextFormatter.formatClock(snapshot.overtimeElapsed),
                snoozeMinutes: Int(settingsStore.settings.snoozeMinutes)
            )
        } else {
            overlay.hide()
        }
    }

    private func notifyCameraFallback() {
        notifications.post(
            title: "Camera unavailable",
            body: "SightSave is using keyboard & mouse activity instead. You can change this in Settings.",
            sound: false
        )
    }

    func openSettings() {
        if settingsWindow == nil {
            let root = SettingsView(
                store: settingsStore,
                onClose: { [weak self] in self?.settingsWindow?.orderOut(nil) },
                cameraDenied: presenceMonitor.cameraDenied,
                notificationsDenied: !notifications.authorizationGranted
            )
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "SightSave Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 500, height: 640))
            window.center()
            settingsWindow = window
        } else if let hosting = settingsWindow?.contentViewController as? NSHostingController<SettingsView> {
            hosting.rootView = SettingsView(
                store: settingsStore,
                onClose: { [weak self] in self?.settingsWindow?.orderOut(nil) },
                cameraDenied: presenceMonitor.cameraDenied,
                notificationsDenied: !notifications.authorizationGranted
            )
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
