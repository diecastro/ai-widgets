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
