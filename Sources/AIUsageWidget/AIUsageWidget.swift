import WidgetKit
import SwiftUI
import UsageCore

/// The widget only ever reads the snapshot the app wrote.
///
/// WidgetKit extensions are always sandboxed, so reaching into `~/.claude` or
/// `~/.codex` from here would fail. All collection stays in the app; this is the
/// read side of the App Group container.
struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageTimelineProvider: TimelineProvider {
    private let store = SnapshotStore.reader()

    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let snapshot = store.read()
        completion(UsageEntry(date: .now,
                              snapshot: snapshot.providers.isEmpty ? .placeholder : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let now = Date()
        let snapshot = store.read()
        let entry = UsageEntry(date: now, snapshot: snapshot)

        // Reload at the next reset so the rollover to 0% lands on time, rather
        // than showing a spent quota until some arbitrary interval elapses.
        // Floored at 15 minutes because WidgetKit coalesces anything tighter.
        let nextReset = snapshot.nextReset(after: now)
        let refreshAt = max(nextReset ?? now.addingTimeInterval(1800),
                            now.addingTimeInterval(900))
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
    }
}

extension UsageSnapshot {
    /// Shown in the widget gallery and before the app has ever run.
    static let placeholder = UsageSnapshot(
        providers: [
            ProviderSnapshot(provider: .claudeCode, windows: [
                QuotaWindow(kind: .fiveHour, usedPercent: 43, resetsAt: .now.addingTimeInterval(9000)),
                QuotaWindow(kind: .weekly, usedPercent: 81, resetsAt: .now.addingTimeInterval(115_000))
            ], observedAt: .now),
            ProviderSnapshot(provider: .codex, windows: [
                QuotaWindow(kind: .fiveHour, usedPercent: 12, resetsAt: .now.addingTimeInterval(6000))
            ], observedAt: .now)
        ],
        generatedAt: .now)
}

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget { AIUsageWidget() }
}

struct AIUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AIUsageWidget", provider: UsageTimelineProvider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AI Usage")
        .description("How close you are to each AI tool's rate limit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
