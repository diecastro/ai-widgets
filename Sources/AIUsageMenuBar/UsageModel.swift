import Foundation
import Observation
import WidgetKit
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

    private var hasReloadedWidget = false
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

        let updated = await refresher.refresh()
        let changed = updated != snapshot
        snapshot = updated
        now = .now

        // The widget has no way to notice the shared snapshot changed — it only
        // rebuilds its timeline when asked, or when its own reload policy fires.
        // Reloading only on an actual change keeps this off WidgetKit's budget
        // during the 60s poll, which usually finds nothing new.
        // Forced once on launch too: the model starts from the same snapshot on
        // disk, so nothing would look "changed" even though the widget may have
        // been rendering stale data — or none — since before the app started.
        if changed || !hasReloadedWidget {
            hasReloadedWidget = true
            WidgetCenter.shared.reloadAllTimelines()
        }
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
