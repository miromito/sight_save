import AppKit
import SightSaveCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    var onPauseResume: (() -> Void)?
    var onReset: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private var pauseItem: NSMenuItem!
    private var stateItem: NSMenuItem!
    private var detailItem: NSMenuItem!

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureMenu()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "SightSave")
            button.imagePosition = .imageLeading
            button.title = "Away"
            button.toolTip = "SightSave"
        }
    }

    private func configureMenu() {
        stateItem = NSMenuItem(title: "Status: Away", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        detailItem = NSMenuItem(title: " ", action: nil, keyEquivalent: "")
        detailItem.isEnabled = false
        menu.addItem(detailItem)

        menu.addItem(.separator())

        pauseItem = NSMenuItem(
            title: "Pause",
            action: #selector(pauseResume),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let reset = NSMenuItem(
            title: "Reset Session",
            action: #selector(resetSession),
            keyEquivalent: "r"
        )
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit SightSave",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func update(snapshot: SessionSnapshot, settings: AppSettings) {
        statusItem.button?.title = " " + snapshot.statusText
        statusItem.button?.toolTip = tooltip(for: snapshot, settings: settings)

        stateItem.title = "Status: \(phaseLabel(snapshot.phase))"
        var details: [String] = []
        if snapshot.isInCall { details.append("On a call") }
        if snapshot.phase == .working || snapshot.phase == .overtime {
            details.append("Work \(StatusTextFormatter.formatClock(snapshot.workElapsed))")
        }
        if snapshot.phase == .overtime {
            details.append("Over +\(StatusTextFormatter.formatClock(snapshot.overtimeElapsed))")
        }
        if snapshot.phase == .resting {
            details.append("Rest \(StatusTextFormatter.formatClock(snapshot.restElapsed)) / \(Int(settings.restMinutes))m")
        }
        if snapshot.phase == .settling {
            details.append("Present \(StatusTextFormatter.formatClock(snapshot.presenceAccumulated)) / \(Int(settings.presenceThresholdMinutes))m")
        }
        detailItem.title = details.isEmpty ? "Waiting for presence…" : details.joined(separator: " · ")

        pauseItem.title = snapshot.isPaused ? "Resume" : "Pause"
    }

    private func phaseLabel(_ phase: SessionPhase) -> String {
        switch phase {
        case .inactive: return "Away"
        case .settling: return "Settling in"
        case .working: return "Working"
        case .overtime: return "Overtime — take a break"
        case .resting: return "Resting"
        case .paused: return "Paused"
        }
    }

    private func tooltip(for snapshot: SessionSnapshot, settings: AppSettings) -> String {
        """
        SightSave — \(phaseLabel(snapshot.phase))
        Work limit: \(Int(settings.workLimitMinutes)) min · Rest: \(Int(settings.restMinutes)) min
        """
    }

    @objc private func pauseResume() { onPauseResume?() }
    @objc private func resetSession() { onReset?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func quit() { onQuit?() }
}
