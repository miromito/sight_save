import Foundation

/// User-configurable preferences persisted via `UserDefaults` in the app target.
public struct AppSettings: Equatable, Sendable {
    public var presenceThresholdMinutes: Double
    public var workLimitMinutes: Double
    public var restMinutes: Double
    public var checkIntervalSeconds: Double
    public var detectionMode: DetectionMode
    public var warningStyle: WarningStyle
    public var snoozeMinutes: Double
    public var restDoneSoundName: String
    public var callBehavior: CallBehavior
    public var longCallNudgeMinutes: Double
    public var longCallNudgeEnabled: Bool
    public var launchAtLogin: Bool

    public static let defaultRestDoneSound = "Glass"

    public static let `default` = AppSettings(
        presenceThresholdMinutes: 2,
        workLimitMinutes: 50,
        restMinutes: 5,
        checkIntervalSeconds: 5,
        detectionMode: .hybrid,
        warningStyle: .overlay,
        snoozeMinutes: 5,
        restDoneSoundName: defaultRestDoneSound,
        callBehavior: .silentOnly,
        longCallNudgeMinutes: 60,
        longCallNudgeEnabled: true,
        launchAtLogin: false
    )

    public init(
        presenceThresholdMinutes: Double,
        workLimitMinutes: Double,
        restMinutes: Double,
        checkIntervalSeconds: Double,
        detectionMode: DetectionMode,
        warningStyle: WarningStyle,
        snoozeMinutes: Double,
        restDoneSoundName: String,
        callBehavior: CallBehavior,
        longCallNudgeMinutes: Double,
        longCallNudgeEnabled: Bool,
        launchAtLogin: Bool
    ) {
        self.presenceThresholdMinutes = presenceThresholdMinutes
        self.workLimitMinutes = workLimitMinutes
        self.restMinutes = restMinutes
        self.checkIntervalSeconds = checkIntervalSeconds
        self.detectionMode = detectionMode
        self.warningStyle = warningStyle
        self.snoozeMinutes = snoozeMinutes
        self.restDoneSoundName = restDoneSoundName
        self.callBehavior = callBehavior
        self.longCallNudgeMinutes = longCallNudgeMinutes
        self.longCallNudgeEnabled = longCallNudgeEnabled
        self.launchAtLogin = launchAtLogin
    }

    public var presenceThreshold: TimeInterval { presenceThresholdMinutes * 60 }
    public var workLimit: TimeInterval { workLimitMinutes * 60 }
    public var restDuration: TimeInterval { restMinutes * 60 }
    public var snoozeDuration: TimeInterval { snoozeMinutes * 60 }
    public var longCallNudge: TimeInterval { longCallNudgeMinutes * 60 }
}

public enum DetectionMode: String, CaseIterable, Codable, Sendable {
    case camera
    case keyboardMouse
    case hybrid

    public var displayName: String {
        switch self {
        case .camera: return "Camera (face detection)"
        case .keyboardMouse: return "Keyboard & mouse only"
        case .hybrid: return "Hybrid (input first, then camera)"
        }
    }
}

public enum WarningStyle: String, CaseIterable, Codable, Sendable {
    case notification
    case overlay

    public var displayName: String {
        switch self {
        case .notification: return "macOS notification"
        case .overlay: return "Full-screen overlay"
        }
    }
}

public enum CallBehavior: String, CaseIterable, Codable, Sendable {
    case dontDisturb
    case silentOnly
    case normal

    public var displayName: String {
        switch self {
        case .dontDisturb: return "Don't disturb"
        case .silentOnly: return "Silent notification only"
        case .normal: return "Normal"
        }
    }
}
