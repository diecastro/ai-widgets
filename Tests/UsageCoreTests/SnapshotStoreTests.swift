import Foundation
import Testing
@testable import UsageCore

@Suite("SnapshotStore and UsageRefresher")
struct SnapshotStoreTests {
    private func tempStore() -> (SnapshotStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("store-\(UUID().uuidString)")
        return (SnapshotStore(fileURL: dir.appendingPathComponent("snapshot.json")), dir)
    }

    @Test func `round-trips a snapshot`() throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = UsageSnapshot(
            providers: [ProviderSnapshot(
                provider: .claudeCode,
                windows: [QuotaWindow(kind: .fiveHour, usedPercent: 39, resetsAt: Date())],
                observedAt: Date())],
            generatedAt: Date())

        try store.write(original)
        #expect(store.read() == original)
    }

    @Test func `reads empty when nothing has been written`() {
        let (store, _) = tempStore()
        #expect(store.read() == .empty)
    }

    @Test func `keeps a provider's previous reading when it yields nothing`() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let previous = ProviderSnapshot(
            provider: .codex,
            windows: [QuotaWindow(kind: .weekly, usedPercent: 2, resetsAt: nil)],
            observedAt: Date(timeIntervalSince1970: 1_789_000_000))
        try store.write(UsageSnapshot(providers: [previous], generatedAt: Date()))

        let refresher = UsageRefresher(providers: [FailingProvider(id: .codex)], store: store)
        let result = await refresher.refresh()

        #expect(result.snapshot(for: .codex) == previous)
    }

    @Test func `one failing provider does not block the others`() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let working = StubProvider(id: .claudeCode, percent: 39)
        let refresher = UsageRefresher(providers: [FailingProvider(id: .codex), working], store: store)
        let result = await refresher.refresh()

        #expect(result.providers.count == 1)
        #expect(result.snapshot(for: .claudeCode)?.windows.first?.usedPercent == 39)
    }

    @Test func `orders providers consistently regardless of completion order`() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let refresher = UsageRefresher(
            providers: [StubProvider(id: .codex, percent: 2), StubProvider(id: .claudeCode, percent: 39)],
            store: store)
        let result = await refresher.refresh()

        #expect(result.providers.map(\.provider) == [.claudeCode, .codex])
    }
}

private struct StubProvider: UsageProvider {
    let id: ProviderID
    let percent: Double
    func fetch() async throws -> ProviderSnapshot {
        ProviderSnapshot(provider: id,
                         windows: [QuotaWindow(kind: .fiveHour, usedPercent: percent, resetsAt: nil)],
                         observedAt: Date())
    }
}

private struct FailingProvider: UsageProvider {
    let id: ProviderID
    func fetch() async throws -> ProviderSnapshot { throw ProviderError.noData("stub") }
}
