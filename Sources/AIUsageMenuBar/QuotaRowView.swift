import SwiftUI
import UsageCore

/// One quota window: label, bar, percentage, and when it resets.
///
/// The bar and the number carry the same information deliberately — the bar is
/// read at a glance, the number when you need precision.
struct QuotaRowView: View {
    let window: QuotaWindow
    let freshness: Freshness
    let now: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var percent: Double { window.effectiveUsedPercent(asOf: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(window.longLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let note = freshness.note {
                    Text(note)
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                }

                Spacer(minLength: 4)

                Text(percent, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    + Text("%").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(freshness == .fresh ? .primary : .secondary)

            bar

            if let resetsAt = window.resetsAt, resetsAt > now {
                Text("resets \(countdown(to: resetsAt, from: now))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(UsageStyle.tint(for: percent))
                    .frame(width: max(0, proxy.size.width * percent / 100))
                    .opacity(freshness == .fresh ? 1 : 0.55)
            }
        }
        .frame(height: UsageStyle.barHeight)
        .animation(reduceMotion ? nil : UsageStyle.valueChange, value: percent)
        .accessibilityElement()
        .accessibilityLabel(window.longLabel)
        .accessibilityValue("\(Int(percent)) percent used")
    }
}
