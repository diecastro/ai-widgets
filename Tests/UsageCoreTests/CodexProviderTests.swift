import Foundation
import Testing
@testable import UsageCore

@Suite("CodexProvider")
struct CodexProviderTests {

    @Test func `reads both windows from a real rollout`() throws {
        let snap = try CodexProvider.parse(Fixture.data("codex-rollout.jsonl"))
        #expect(snap.provider == .codex)
        #expect(try #require(snap.window(.fiveHour)).usedPercent == 10.0)
        #expect(try #require(snap.window(.weekly)).usedPercent == 2.0)
    }

    @Test func `labels windows by length, not by primary or secondary position`() throws {
        let snap = try CodexProvider.parse(Fixture.data("codex-rollout.jsonl"))
        #expect(snap.windows.map(\.kind) == [.fiveHour, .weekly])
    }

    @Test func `parses the event timestamp as observedAt`() throws {
        let snap = try CodexProvider.parse(Fixture.data("codex-rollout.jsonl"))
        #expect(snap.observedAt > Date(timeIntervalSince1970: 1_750_000_000))
        #expect(snap.observedAt < Date())
    }

    @Test func `reports no data when no event carries rate limits`() throws {
        let data = try Fixture.data("codex-no-limits.jsonl")
        #expect(throws: ProviderError.self) { try CodexProvider.parse(data) }
    }

    @Test func `picks the most constrained window`() throws {
        let snap = try CodexProvider.parse(Fixture.data("codex-rollout.jsonl"))
        // Pinned before the 5h window's reset; at 10% vs the weekly 2% it leads.
        let beforeReset = try #require(snap.window(.fiveHour)?.resetsAt).addingTimeInterval(-60)
        #expect(try #require(snap.mostConstrained(asOf: beforeReset)).kind == .fiveHour)
    }

    @Test func `prefers a live window over one that has already reset`() throws {
        let snap = try CodexProvider.parse(Fixture.data("codex-rollout.jsonl"))
        // After the 5h reset it reads 0%, so the 2% weekly window is the binding one.
        let afterReset = try #require(snap.window(.fiveHour)?.resetsAt).addingTimeInterval(60)
        #expect(try #require(snap.mostConstrained(asOf: afterReset)).kind == .weekly)
    }

    @Test func `finds the newest rollout anywhere in the date tree`() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-test-\(UUID().uuidString)")
        let old = root.appendingPathComponent("2026/09/15")
        let new = root.appendingPathComponent("2026/09/16")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let older = old.appendingPathComponent("rollout-a.jsonl")
        let newer = new.appendingPathComponent("rollout-b.jsonl")
        try Data("{}".utf8).write(to: older)
        try Data("{}".utf8).write(to: newer)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: older.path)

        // The enumerator canonicalises /var to /private/var, so compare resolved paths.
        #expect(CodexProvider.newestRollout(under: root)?.resolvingSymlinksInPath()
                == newer.resolvingSymlinksInPath())
    }

    @Test func `ignores files that are not rollouts`() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("{}".utf8).write(to: root.appendingPathComponent("notes.jsonl"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("rollout-x.txt"))

        #expect(CodexProvider.newestRollout(under: root) == nil)
    }
}
