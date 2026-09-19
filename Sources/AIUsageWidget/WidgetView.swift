import WidgetKit
import SwiftUI
import UsageCore

/// The widget cannot refresh on demand, so it states what it knows and how old
/// it is rather than implying the numbers are current.
struct WidgetView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) private var family

    private var now: Date { entry.date }
    private var providers: [ProviderSnapshot] { entry.snapshot.providers }

    var body: some View {
        if providers.isEmpty {
            emptyState
        } else {
            switch family {
            case .systemSmall: smallBody
            default: mediumBody
            }
        }
    }

    /// Small: one line per provider, the most constrained window only. At this
    /// size an extra row costs more legibility than the detail is worth.
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ForEach(providers, id: \.provider) { provider in
                if let window = provider.mostConstrained(asOf: now) {
                    compactRow(provider, window)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Medium: every window, since there is room for the session/weekly split
    /// that actually drives a decision.
    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            ForEach(providers, id: \.provider) { provider in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(provider.provider.displayName)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(relativeAge(of: provider.observedAt, from: now))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(provider.windows, id: \.kind) { window in
                        HStack(spacing: 7) {
                            Text(window.kind.shortLabel)
                                .font(.system(size: 9, weight: .medium).monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .leading)
                            meter(for: window, in: provider)
                            Text("\(Int(window.effectiveUsedPercent(asOf: now)))%")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 10, weight: .semibold))
            Text("AI Usage")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func compactRow(_ provider: ProviderSnapshot, _ window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(provider.provider.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(Int(window.effectiveUsedPercent(asOf: now)))%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            meter(for: window, in: provider)
        }
    }

    private func meter(for window: QuotaWindow, in provider: ProviderSnapshot) -> some View {
        let percent = window.effectiveUsedPercent(asOf: now)
        let isFresh = Freshness.of(provider, window: window, asOf: now) == .fresh
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint(for: percent))
                    .frame(width: max(0, proxy.size.width * percent / 100))
                    .opacity(isFresh ? 1 : 0.5)
            }
        }
        .frame(height: 5)
    }

    private func tint(for percent: Double) -> Color {
        switch percent {
        case 80...: .red
        case 50...: .orange
        default: .green
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            Text("No data yet")
                .font(.system(size: 12, weight: .semibold))
            Text("Open AI Usage and run one of your tools.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

private func relativeAge(of date: Date, from now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 90 { return "now" }
    if seconds < 5400 { return "\(seconds / 60)m" }
    if seconds < 172_800 { return "\(seconds / 3600)h" }
    return "\(seconds / 86400)d"
}
