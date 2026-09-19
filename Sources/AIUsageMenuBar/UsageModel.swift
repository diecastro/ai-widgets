import Foundation
import Observation
import UsageCore

/// The seam between the async collection layer and the views.
///
/// Views stay synchronous and read `snapshot`; the refresher mutates it when a
/// fetch lands. `now` is stored rather than read ad hoc so every countdown,
/// staleness note and reset rollover in a single render agrees.
@MainActor
@Observable
final class UsageModel {
    private(set) var snapshot: UsageSnapshot
    private(set) var now: Date = .now
    private(set) var isRefreshing = false

    private let refresher: UsageRefresher
    private let store: SnapshotStore

    init(store: SnapshotStore = SnapshotStore()) {
        self.store = store
        self.refresher = .local(store: store)
        self.snapshot = store.read()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        snapshot = await refresher.refresh()
        now = .now
    }

    /// Advances the clock so countdowns tick and a passed reset flips to 0%
    /// without waiting for a provider to report again.
    func tick() {
        now = .now
    }

    var providers: [ProviderSnapshot] { snapshot.providers }
    var peakPercent: Double? { snapshot.peakUsedPercent(asOf: now) }

    func freshness(_ snapshot: ProviderSnapshot, _ window: QuotaWindow) -> Freshness {
        Freshness.of(snapshot, window: window, asOf: now)
    }
}
