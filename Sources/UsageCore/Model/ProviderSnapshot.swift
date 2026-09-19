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

    /// The window closest to its limit, which is what a compact surface shows.
    public func mostConstrained(asOf now: Date) -> QuotaWindow? {
        windows.max { $0.effectiveUsedPercent(asOf: now) < $1.effectiveUsedPercent(asOf: now) }
    }
}
