import SightSaveCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    var onClose: () -> Void
    var cameraDenied: Bool
    var notificationsDenied: Bool

    var body: some View {
        Form {
            if cameraDenied || notificationsDenied {
                Section("Permissions") {
                    if cameraDenied {
                        Text("Camera access is denied. SightSave fell back to keyboard & mouse detection. Enable camera in System Settings → Privacy & Security → Camera.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    if notificationsDenied {
                        Text("Notifications are disabled. Enable them in System Settings → Notifications → SightSave.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            }

            Section("Timing") {
                stepperRow(
                    title: "Presence / away threshold (X)",
                    value: $store.settings.presenceThresholdMinutes,
                    range: 0.5...30,
                    step: 0.5,
                    help: "Minutes of continuous presence before work starts, and minutes away before rest starts."
                )
                stepperRow(
                    title: "Work limit (Y)",
                    value: $store.settings.workLimitMinutes,
                    range: 5...180,
                    step: 1,
                    help: "Minutes of work before a break warning."
                )
                stepperRow(
                    title: "Rest duration (Z)",
                    value: $store.settings.restMinutes,
                    range: 1...60,
                    step: 1,
                    help: "Minutes away required to complete a rest and reset the session."
                )
                stepperRow(
                    title: "Check interval (seconds)",
                    value: $store.settings.checkIntervalSeconds,
                    range: 2...60,
                    step: 1,
                    help: "How often presence is sampled."
                )
            }

            Section("Detection") {
                Picker("Mode", selection: $store.settings.detectionMode) {
                    ForEach(DetectionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .accessibilityLabel("Presence detection mode")
            }

            Section("Break warning") {
                Picker("Style", selection: $store.settings.warningStyle) {
                    ForEach(WarningStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .accessibilityLabel("Break warning style")

                stepperRow(
                    title: "Snooze length",
                    value: $store.settings.snoozeMinutes,
                    range: 1...30,
                    step: 1,
                    help: "Minutes to wait after snoozing before warning again."
                )
            }

            Section("Rest complete") {
                Picker("Sound", selection: $store.settings.restDoneSoundName) {
                    ForEach(SoundPlayer.systemSoundNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .accessibilityLabel("Rest complete sound")

                Button("Preview sound") {
                    SoundPlayer.play(named: store.settings.restDoneSoundName)
                }
                .accessibilityLabel("Preview rest complete sound")
            }

            Section("Video calls") {
                Picker("During calls", selection: $store.settings.callBehavior) {
                    ForEach(CallBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .accessibilityLabel("Behavior during video calls")

                Toggle("Gentle nudge for long calls", isOn: $store.settings.longCallNudgeEnabled)
                    .accessibilityLabel("Gentle nudge for long calls")

                if store.settings.longCallNudgeEnabled {
                    stepperRow(
                        title: "Nudge after (minutes)",
                        value: $store.settings.longCallNudgeMinutes,
                        range: 15...180,
                        step: 5,
                        help: "Suggest standing up after this many minutes on a call."
                    )
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { newValue in
                        store.settings.launchAtLogin = newValue
                        _ = LaunchAtLogin.setEnabled(newValue)
                    }
                ))
                .accessibilityLabel("Launch SightSave at login")

                Button("Reset settings to defaults") {
                    store.resetToDefaults()
                }
                .accessibilityLabel("Reset settings to defaults")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 460, minHeight: 520)
        .navigationTitle("SightSave Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onClose() }
                    .accessibilityLabel("Close settings")
            }
        }
    }

    @ViewBuilder
    private func stepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        help: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(display(value.wrappedValue, step: step))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(display(value.wrappedValue, step: step))
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func display(_ value: Double, step: Double) -> String {
        if step >= 1 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
