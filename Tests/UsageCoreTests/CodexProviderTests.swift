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
        #expect(try #require(snap.mostConstrained(asOf: Date())).kind == .fiveHour)
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

        #expect(CodexProvider.newestRollout(under: root) == newer)
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
