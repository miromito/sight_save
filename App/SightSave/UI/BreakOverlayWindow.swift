import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController {
    private var window: NSWindow?
    var onSnooze: (() -> Void)?
    var onDismiss: (() -> Void)?

    func show(overtimeText: String, snoozeMinutes: Int) {
        if window == nil {
            let view = BreakOverlayView(
                overtimeText: overtimeText,
                snoozeMinutes: snoozeMinutes,
                onSnooze: { [weak self] in self?.onSnooze?() },
                onDismiss: { [weak self] in self?.onDismiss?() }
            )
            let hosting = NSHostingView(rootView: view)
            let screen = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 800, height: 600)
            let window = NSWindow(
                contentRect: screen,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.contentView = hosting
            self.window = window
        } else if let hosting = window?.contentView as? NSHostingView<BreakOverlayView> {
            hosting.rootView = BreakOverlayView(
                overtimeText: overtimeText,
                snoozeMinutes: snoozeMinutes,
                onSnooze: { [weak self] in self?.onSnooze?() },
                onDismiss: { [weak self] in self?.onDismiss?() }
            )
        }

        window?.setFrame(NSScreen.main?.frame ?? .zero, display: true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func updateOvertimeText(_ text: String, snoozeMinutes: Int) {
        guard window?.isVisible == true else { return }
        show(overtimeText: text, snoozeMinutes: snoozeMinutes)
    }
}

struct BreakOverlayView: View {
    let overtimeText: String
    let snoozeMinutes: Int
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Time for a break")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("You've been sitting long enough. Stand up, stretch, and rest your eyes.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)

                Text("Overtime \(overtimeText)")
                    .font(.system(size: 22, weight: .medium).monospacedDigit())
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Overtime \(overtimeText)")

                HStack(spacing: 16) {
                    Button("Snooze \(snoozeMinutes) min") {
                        onSnooze()
                    }
                    .keyboardShortcut("s", modifiers: [])
                    .accessibilityLabel("Snooze for \(snoozeMinutes) minutes")

                    Button("Dismiss") {
                        onDismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Dismiss break warning")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
            )
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
