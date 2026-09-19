import Foundation

public enum ProviderID: String, Hashable, Codable, Sendable, CaseIterable {
    case claudeCode
    case codex
    case cursor

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }
}

/// One provider's quota windows, as of the moment the *source* produced them.
public struct ProviderSnapshot: Hashable, Codable, Sendable {
    public let provider: ProviderID
    public let windows: [QuotaWindow]
    /// When the underlying source produced this reading — not when it was read.
    public let observedAt: Date

    public init(provider: ProviderID, windows: [QuotaWindow], observedAt: Date) {
        self.provider = provider
        self.windows = windows
        self.observedAt = observedAt
    }

    public func window(_ kind: WindowKind) -> QuotaWindow? {
        windows.first { $0.kind == kind }
    }

    /// The short rolling window — what "can I keep working right now" depends on.
    ///
    /// Falls back to the most constrained window for a provider that reports no
    /// five-hour limit, so a compact surface still shows something meaningful.
    public func sessionWindow(asOf now: Date) -> QuotaWindow? {
        window(.fiveHour) ?? mostConstrained(asOf: now)
    }

    /// The window closest to its limit.
    public func mostConstrained(asOf now: Date) -> QuotaWindow? {
        windows.max { $0.effectiveUsedPercent(asOf: now) < $1.effectiveUsedPercent(asOf: now) }
    }
}
