import AppKit
import Foundation

/// Tracks system sleep and screen lock so timers can pause and presence is treated as away.
@MainActor
final class SleepLockMonitor {
    private(set) var isUnavailable = false
    var onChange: ((Bool) -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setUnavailable(true) }
        })

        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setUnavailable(false) }
        })

        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setUnavailable(true) }
        })

        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setUnavailable(false) }
        })
    }

    func stop() {
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in observers {
            workspace.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()
    }

    private func setUnavailable(_ value: Bool) {
        guard isUnavailable != value else { return }
        isUnavailable = value
        onChange?(value)
    }
}
