import Foundation
import Testing
@testable import UsageCore

@Suite("ClaudeCodeProvider")
struct ClaudeCodeProviderTests {

    @Test func `reads both windows from a statusline cache`() throws {
        let snap = try ClaudeCodeProvider.parse(Fixture.data("claude-normal.json"))
        #expect(snap.provider == .claudeCode)
        #expect(snap.windows.count == 2)
        #expect(try #require(snap.window(.fiveHour)).usedPercent == 62.4)
        #expect(try #require(snap.window(.weekly)).usedPercent == 41.0)
        #expect(try #require(snap.window(.fiveHour)).resetsAt != nil)
    }

    @Test func `surfaces the rolled-over window as zero`() throws {
        let snap = try ClaudeCodeProvider.parse(Fixture.data("claude-rolled-over.json"))
        let fiveHour = try #require(snap.window(.fiveHour))
        // The sampled value is preserved; only the rendered value drops to zero.
        #expect(fiveHour.usedPercent == 88.0)
        #expect(fiveHour.effectiveUsedPercent(asOf: Date()) == 0)
        #expect(try #require(snap.window(.weekly)).effectiveUsedPercent(asOf: Date()) == 41.0)
    }

    @Test func `yields no windows when the API reported no limits`() throws {
        let snap = try ClaudeCodeProvider.parse(Fixture.data("claude-empty.json"))
        #expect(snap.windows.isEmpty)
        #expect(snap.mostConstrained(asOf: Date()) == nil)
    }

    @Test func `rejects malformed json`() throws {
        let data = try Fixture.data("claude-malformed.json")
        #expect(throws: ProviderError.self) { try ClaudeCodeProvider.parse(data) }
    }

    @Test func `reports no data when the cache file is absent`() async throws {
        let missing = URL(fileURLWithPath: "/nonexistent/ai-usage/claude.json")
        await #expect(throws: ProviderError.noData("no statusline cache at \(missing.path)")) {
            try await ClaudeCodeProvider(cacheURL: missing).fetch()
        }
    }
}
