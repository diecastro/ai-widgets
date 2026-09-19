import AppKit
import UsageCore

/// Builds the status item's title.
///
/// Every provider with data gets an initial and a percentage, each tinted by its
/// own severity, so the menu bar answers "which tool is running out" without a
/// click. Stale readings are dimmed rather than hidden — omitting them would
/// imply a tool is fine when it is only unmeasured.
enum MenuBarLabel {
    static func attributedTitle(for snapshot: UsageSnapshot, now: Date) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let entries = snapshot.providers.compactMap { provider -> (String, Double, Bool)? in
            guard let window = provider.mostConstrained(asOf: now) else { return nil }
            let freshness = Freshness.of(provider, window: window, asOf: now)
            return (String(provider.provider.displayName.prefix(1)),
                    window.effectiveUsedPercent(asOf: now),
                    freshness != .stale)
        }

        guard !entries.isEmpty else {
            return NSAttributedString(string: "–", attributes: [
                .font: font, .foregroundColor: NSColor.tertiaryLabelColor
            ])
        }

        for (index, entry) in entries.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
            let (initial, percent, isCurrent) = entry
            let color = tint(for: percent, isCurrent: isCurrent)
            result.append(NSAttributedString(
                string: "\(initial) \(Int(percent.rounded()))",
                attributes: [.font: font, .foregroundColor: color]))
        }
        return result
    }

    private static func tint(for percent: Double, isCurrent: Bool) -> NSColor {
        let base: NSColor = switch percent {
        case UsageStyle.criticalThreshold...: .systemRed
        case UsageStyle.cautionThreshold...: .systemOrange
        default: .labelColor
        }
        return isCurrent ? base : base.withAlphaComponent(0.45)
    }
}
