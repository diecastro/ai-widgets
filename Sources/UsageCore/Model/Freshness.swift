import Foundation

/// How much to trust a reading, given how long ago its source produced it.
///
/// Quota data only refreshes while a CLI session is running, so a reading can be
/// arbitrarily old. Rather than decay or interpolate a value the widget cannot
/// know, each surface renders the confidence alongside the number.
public enum Freshness: Hashable, Sendable {
    /// Sampled recently enough to take at face value.
    case fresh
    /// Old, but the window has not reset — the number is a floor, not a guess.
    case stale
    /// The window reset after this was sampled, so the reading is certainly zero.
    case reset

    public static let staleThreshold: TimeInterval = 6 * 60 * 60

    public static func of(
        _ snapshot: ProviderSnapshot,
        window: QuotaWindow,
        asOf now: Date,
        staleAfter: TimeInterval = Freshness.staleThreshold
    ) -> Freshness {
        if window.hasReset(asOf: now) { return .reset }
        return now.timeIntervalSince(snapshot.observedAt) > staleAfter ? .stale : .fresh
    }
}
