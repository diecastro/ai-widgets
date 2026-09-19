import SwiftUI
import UsageCore

/// Visual vocabulary shared by the menu bar and the popover.
///
/// Every value here is deliberate rather than incidental: thresholds match the
/// points where a quota actually changes your behaviour, and the single spring
/// is critically damped because nothing in this interface is momentum-driven —
/// overshoot on a number that merely updated would read as noise.
enum UsageStyle {
    /// Below this, the quota is not worth thinking about.
    static let cautionThreshold: Double = 50
    /// Above this, it should change what you do next.
    static let criticalThreshold: Double = 80

    static func tint(for percent: Double) -> Color {
        switch percent {
        case criticalThreshold...: .red
        case cautionThreshold...: .orange
        default: .green
        }
    }

    /// Critically damped: reaches the new value quickly and settles without bounce.
    static let valueChange = Animation.spring(response: 0.35, dampingFraction: 1.0)

    static let barHeight: CGFloat = 6
    static let popoverWidth: CGFloat = 268
}

extension QuotaWindow {
    var longLabel: String {
        switch kind {
        case .fiveHour: "Session"
        case .weekly: "Weekly"
        case .spendLimit: "Spend"
        case .other: kind.shortLabel
        }
    }
}

extension Freshness {
    var note: String? {
        switch self {
        case .fresh: nil
        case .stale: "stale"
        case .reset: "reset"
        }
    }
}

/// "in 3h 41m" — a countdown is more actionable than a wall-clock time, because
/// the question is always "how long until I can keep going".
func countdown(to date: Date, from now: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let hours = seconds / 3600, minutes = (seconds % 3600) / 60
    if hours >= 24 { return "in \(hours / 24)d \(hours % 24)h" }
    if hours > 0 { return "in \(hours)h \(minutes)m" }
    return "in \(minutes)m"
}

func relativeAge(of date: Date, from now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 90 { return "just now" }
    if seconds < 5400 { return "\(seconds / 60)m ago" }
    if seconds < 172_800 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
}
