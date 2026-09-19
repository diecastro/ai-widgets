import Foundation
import Testing
@testable import UsageCore

@Suite("Freshness")
struct FreshnessTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(observedAgo: TimeInterval, resetsIn: TimeInterval?) -> (ProviderSnapshot, QuotaWindow) {
        let window = QuotaWindow(kind: .fiveHour, usedPercent: 62,
                                 resetsAt: resetsIn.map { now.addingTimeInterval($0) })
        let snap = ProviderSnapshot(provider: .claudeCode, windows: [window],
                                    observedAt: now.addingTimeInterval(-observedAgo))
        return (snap, window)
    }

    @Test func `a recent reading is fresh`() {
        let (s, w) = snapshot(observedAgo: 600, resetsIn: 3600)
        #expect(Freshness.of(s, window: w, asOf: now) == .fresh)
    }

    @Test func `an old reading whose window still stands is stale`() {
        let (s, w) = snapshot(observedAgo: 7 * 3600, resetsIn: 3600)
        #expect(Freshness.of(s, window: w, asOf: now) == .stale)
    }

    @Test func `a crossed reset outranks staleness`() {
        let (s, w) = snapshot(observedAgo: 40 * 3600, resetsIn: -60)
        #expect(Freshness.of(s, window: w, asOf: now) == .reset)
    }
}
