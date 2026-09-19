import Foundation
import os

/// Collects from every provider and publishes one snapshot.
///
/// Providers are queried concurrently and independently: a provider that has no
/// data, or fails outright, drops out of the result instead of failing the
/// refresh. That matters because "Codex hasn't run today" is the normal case,
/// not an error.
public struct UsageRefresher: Sendable {
    private let providers: [any UsageProvider]
    private let store: SnapshotStore
    private static let log = Logger(subsystem: "com.aiusage", category: "refresh")

    public init(providers: [any UsageProvider], store: SnapshotStore) {
        self.providers = providers
        self.store = store
    }

    public static func local(store: SnapshotStore = SnapshotStore()) -> UsageRefresher {
        UsageRefresher(providers: [ClaudeCodeProvider(), CodexProvider()], store: store)
    }

    /// Fetches everything, writes the snapshot, and returns it.
    ///
    /// A provider that reports no data keeps its previous reading if one exists,
    /// so a transient gap — a rotated Codex rollout, a cache file mid-rename —
    /// does not blank the display.
    @discardableResult
    public func refresh(now: Date = Date()) async -> UsageSnapshot {
        let previous = store.read()

        var collected: [ProviderID: ProviderSnapshot] = [:]
        await withTaskGroup(of: (ProviderID, ProviderSnapshot?).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return (provider.id, try await provider.fetch())
                    } catch {
                        Self.log.debug("\(provider.id.rawValue) yielded nothing: \(error)")
                        return (provider.id, nil)
                    }
                }
            }
            for await (id, snapshot) in group {
                collected[id] = snapshot ?? previous.snapshot(for: id)
            }
        }

        // Stable order so the menu bar and widget don't reshuffle between refreshes.
        let ordered = ProviderID.allCases.compactMap { collected[$0] }
        let snapshot = UsageSnapshot(providers: ordered, generatedAt: now)

        do {
            try store.write(snapshot)
        } catch {
            Self.log.error("could not write snapshot: \(error)")
        }
        return snapshot
    }
}
