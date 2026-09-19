import Foundation
import UsageCore

/// A diagnostic CLI: reads every local provider and prints what the menu bar and
/// widget would render. Used to verify ingest end to end without launching the app.
///
///     usage-probe            # read the live sources
///     usage-probe <dir>      # read fixtures from a directory instead

let now = Date()
let args = CommandLine.arguments.dropFirst()

let providers: [any UsageProvider] = if let root = args.first {
    [ClaudeCodeProvider(cacheURL: URL(fileURLWithPath: root).appendingPathComponent("claude-normal.json")),
     CodexProvider(sessionsRoot: URL(fileURLWithPath: root))]
} else {
    [ClaudeCodeProvider(), CodexProvider()]
}

func bar(_ percent: Double, width: Int = 12) -> String {
    let filled = Int((percent / 100 * Double(width)).rounded())
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}

func ago(_ date: Date) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 90 { return "\(seconds)s ago" }
    if seconds < 5400 { return "\(seconds / 60)m ago" }
    return "\(seconds / 3600)h ago"
}

var collected: [ProviderSnapshot] = []

for provider in providers {
    do {
        let snapshot = try await provider.fetch()
        collected.append(snapshot)
        print("\(snapshot.provider.displayName)  ·  sampled \(ago(snapshot.observedAt))")
        if snapshot.windows.isEmpty {
            print("  (reported no limits)")
        }
        for window in snapshot.windows {
            let shown = window.effectiveUsedPercent(asOf: now)
            let freshness = Freshness.of(snapshot, window: window, asOf: now)
            let note = switch freshness {
            case .fresh: ""
            case .stale: "  [stale]"
            case .reset: "  [reset]"
            }
            let resets = window.resetsAt.map {
                let minutes = max(0, Int($0.timeIntervalSince(now) / 60))
                return "  resets in \(minutes / 60)h \(minutes % 60)m"
            } ?? ""
            print(String(format: "  %-3@ %@ %5.1f%%%@%@",
                         window.kind.shortLabel as NSString, bar(shown), shown,
                         resets as NSString, note as NSString))
        }
    } catch let error as ProviderError {
        print("\(provider.id.displayName)  ·  \(error)")
    }
    print("")
}

let snapshot = UsageSnapshot(providers: collected, generatedAt: now)
if let peak = snapshot.peakUsedPercent(asOf: now) {
    print(String(format: "peak %.0f%%", peak))
}
if let next = snapshot.nextReset(after: now) {
    print("next reset \(next.formatted(date: .omitted, time: .shortened))")
}
