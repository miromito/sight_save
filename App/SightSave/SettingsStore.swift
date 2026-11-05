import Combine
import Foundation
import SightSaveCore

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key = "SightSave.AppSettings.v1"

    /// Default argument avoided: `@MainActor` inits must not be evaluated in a nonisolated default-arg context.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            settings = decoded.toAppSettings()
        } else {
            settings = .default
        }
    }

    func resetToDefaults() {
        settings = .default
    }

    private func persist() {
        let payload = PersistedSettings(settings: settings)
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: key)
        }
    }
}

private struct PersistedSettings: Codable, Sendable {
    var presenceThresholdMinutes: Double
    var workLimitMinutes: Double
    var restMinutes: Double
    var checkIntervalSeconds: Double
    var detectionMode: String
    var warningStyle: String
    var snoozeMinutes: Double
    var restDoneSoundName: String
    var callBehavior: String
    var longCallNudgeMinutes: Double
    var longCallNudgeEnabled: Bool
    var launchAtLogin: Bool

    init(settings: AppSettings) {
        presenceThresholdMinutes = settings.presenceThresholdMinutes
        workLimitMinutes = settings.workLimitMinutes
        restMinutes = settings.restMinutes
        checkIntervalSeconds = settings.checkIntervalSeconds
        detectionMode = settings.detectionMode.rawValue
        warningStyle = settings.warningStyle.rawValue
        snoozeMinutes = settings.snoozeMinutes
        restDoneSoundName = settings.restDoneSoundName
        callBehavior = settings.callBehavior.rawValue
        longCallNudgeMinutes = settings.longCallNudgeMinutes
        longCallNudgeEnabled = settings.longCallNudgeEnabled
        launchAtLogin = settings.launchAtLogin
    }

    func toAppSettings() -> AppSettings {
        AppSettings(
            presenceThresholdMinutes: presenceThresholdMinutes,
            workLimitMinutes: workLimitMinutes,
            restMinutes: restMinutes,
            checkIntervalSeconds: checkIntervalSeconds,
            detectionMode: DetectionMode(rawValue: detectionMode) ?? .hybrid,
            warningStyle: WarningStyle(rawValue: warningStyle) ?? .overlay,
            snoozeMinutes: snoozeMinutes,
            restDoneSoundName: restDoneSoundName,
            callBehavior: CallBehavior(rawValue: callBehavior) ?? .silentOnly,
            longCallNudgeMinutes: longCallNudgeMinutes,
            longCallNudgeEnabled: longCallNudgeEnabled,
            launchAtLogin: launchAtLogin
        )
    }
}
