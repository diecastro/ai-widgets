import Foundation

/// Everything the menu bar and widget render, written once by the app and read
/// by both. The widget is sandboxed and cannot reach `~/.claude` or `~/.codex`,
/// so this is the only channel between collection and display.
public struct UsageSnapshot: Hashable, Codable, Sendable {
    public let providers: [ProviderSnapshot]
    public let generatedAt: Date

    public init(providers: [ProviderSnapshot], generatedAt: Date) {
        self.providers = providers
        self.generatedAt = generatedAt
    }

    public static let empty = UsageSnapshot(providers: [], generatedAt: .distantPast)

    public func snapshot(for provider: ProviderID) -> ProviderSnapshot? {
        providers.first { $0.provider == provider }
    }

    /// The highest effective usage across every provider — what drives the menu
    /// bar's colour and any warning threshold.
    public func peakUsedPercent(asOf now: Date) -> Double? {
        providers.compactMap { $0.mostConstrained(asOf: now)?.effectiveUsedPercent(asOf: now) }.max()
    }

    /// The soonest upcoming reset, used to schedule the next widget reload so the
    /// rollover to 0% lands on time.
    public func nextReset(after now: Date) -> Date? {
        providers
            .flatMap(\.windows)
            .compactMap(\.resetsAt)
            .filter { $0 > now }
            .min()
    }
}
