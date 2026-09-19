import Foundation

/// Which limit window a reading describes.
///
/// Providers report windows in minutes; ``init(windowMinutes:)`` maps the common
/// ones onto named cases and keeps anything unexpected as ``other`` rather than
/// mislabelling it.
public enum WindowKind: Hashable, Codable, Sendable {
    case fiveHour
    case weekly
    case spendLimit
    case other(minutes: Int)

    public init(windowMinutes: Int) {
        switch windowMinutes {
        case 300: self = .fiveHour
        case 10080: self = .weekly
        default: self = .other(minutes: windowMinutes)
        }
    }

    public var shortLabel: String {
        switch self {
        case .fiveHour: "5h"
        case .weekly: "wk"
        case .spendLimit: "$"
        case .other(let minutes) where minutes % 1440 == 0: "\(minutes / 1440)d"
        case .other(let minutes) where minutes % 60 == 0: "\(minutes / 60)h"
        case .other(let minutes): "\(minutes)m"
        }
    }
}

/// A single quota reading: how much of one window has been consumed, and when it resets.
public struct QuotaWindow: Hashable, Codable, Sendable {
    public let kind: WindowKind
    /// Percentage consumed, clamped to 0...100.
    public let usedPercent: Double
    public let resetsAt: Date?

    public init(kind: WindowKind, usedPercent: Double, resetsAt: Date?) {
        self.kind = kind
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
    }

    /// Whether the window rolled over since it was sampled.
    public func hasReset(asOf now: Date) -> Bool {
        guard let resetsAt else { return false }
        return now >= resetsAt
    }

    /// The percentage to display.
    ///
    /// Once `resetsAt` has passed the window genuinely restarted, so zero is the
    /// correct reading rather than a stale one — the only case where a value can
    /// be asserted without a fresh sample.
    public func effectiveUsedPercent(asOf now: Date) -> Double {
        hasReset(asOf: now) ? 0 : usedPercent
    }
}
