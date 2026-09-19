import Foundation
import Testing
@testable import UsageCore

@Suite("QuotaWindow")
struct QuotaWindowTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `clamps percentages into 0...100`() {
        #expect(QuotaWindow(kind: .fiveHour, usedPercent: 140, resetsAt: nil).usedPercent == 100)
        #expect(QuotaWindow(kind: .fiveHour, usedPercent: -3, resetsAt: nil).usedPercent == 0)
    }

    @Test func `reports zero once the window has reset`() {
        let window = QuotaWindow(kind: .fiveHour, usedPercent: 88, resetsAt: now.addingTimeInterval(-60))
        #expect(window.hasReset(asOf: now))
        #expect(window.effectiveUsedPercent(asOf: now) == 0)
    }

    @Test func `keeps the sampled value before the reset`() {
        let window = QuotaWindow(kind: .fiveHour, usedPercent: 88, resetsAt: now.addingTimeInterval(60))
        #expect(!window.hasReset(asOf: now))
        #expect(window.effectiveUsedPercent(asOf: now) == 88)
    }

    @Test func `a window with no reset date never rolls over`() {
        let window = QuotaWindow(kind: .spendLimit, usedPercent: 50, resetsAt: nil)
        #expect(!window.hasReset(asOf: now))
        #expect(window.effectiveUsedPercent(asOf: now) == 50)
    }

    @Test(arguments: [(300, WindowKind.fiveHour), (10080, .weekly), (1440, .other(minutes: 1440))])
    func `labels windows from their length in minutes`(minutes: Int, expected: WindowKind) {
        #expect(WindowKind(windowMinutes: minutes) == expected)
    }

    @Test func `renders readable short labels for unknown windows`() {
        #expect(WindowKind(windowMinutes: 1440).shortLabel == "1d")
        #expect(WindowKind(windowMinutes: 180).shortLabel == "3h")
        #expect(WindowKind(windowMinutes: 45).shortLabel == "45m")
    }
}

@Suite("Session window selection")
struct SessionWindowTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(_ windows: [QuotaWindow]) -> ProviderSnapshot {
        ProviderSnapshot(provider: .claudeCode, windows: windows, observedAt: now)
    }

    @Test func `prefers the five-hour window even when weekly is higher`() throws {
        // The case that prompted this: a weekly window well above the session one
        // would otherwise win, replacing the number the compact surface is for.
        let snap = snapshot([
            QuotaWindow(kind: .fiveHour, usedPercent: 62, resetsAt: now.addingTimeInterval(3600)),
            QuotaWindow(kind: .weekly, usedPercent: 84, resetsAt: now.addingTimeInterval(90_000))
        ])
        #expect(try #require(snap.sessionWindow(asOf: now)).kind == .fiveHour)
        #expect(try #require(snap.mostConstrained(asOf: now)).kind == .weekly)
    }

    @Test func `falls back when a provider reports no five-hour window`() throws {
        let snap = snapshot([QuotaWindow(kind: .weekly, usedPercent: 12, resetsAt: nil)])
        #expect(try #require(snap.sessionWindow(asOf: now)).kind == .weekly)
    }

    @Test func `is nil when a provider reports nothing`() {
        #expect(snapshot([]).sessionWindow(asOf: now) == nil)
    }
}
