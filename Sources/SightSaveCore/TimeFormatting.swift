import Foundation

public enum TimeFormatting {
    public static func minutesLabel(_ minutes: Double) -> String {
        if minutes == Double(Int(minutes)) {
            return "\(Int(minutes)) min"
        }
        return String(format: "%.1f min", minutes)
    }

    public static func detailedDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}
