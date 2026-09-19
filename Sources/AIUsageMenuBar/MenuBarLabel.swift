import AppKit
import UsageCore

/// Builds the status item's title.
///
/// Every provider with data gets an initial and a percentage, each tinted by its
/// own severity, so the menu bar answers "which tool is running out" without a
/// click. Stale readings are dimmed rather than hidden — omitting them would
/// imply a tool is fine when it is only unmeasured.
enum MenuBarLabel {
    private struct Entry {
        let provider: ProviderID
        let percent: Double
        let isCurrent: Bool
    }

    static func attributedTitle(for snapshot: UsageSnapshot, now: Date) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let entries = snapshot.providers.compactMap { provider -> Entry? in
            guard let window = provider.mostConstrained(asOf: now) else { return nil }
            let freshness = Freshness.of(provider, window: window, asOf: now)
            return Entry(provider: provider.provider,
                         percent: window.effectiveUsedPercent(asOf: now),
                         isCurrent: freshness != .stale)
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
            let color = tint(for: entry.percent, isCurrent: entry.isCurrent)

            // The mark is an attachment rather than a letter, so two providers
            // whose names share an initial stay distinguishable.
            let attachment = NSTextAttachment()
            attachment.image = ProviderGlyph.image(for: entry.provider, tint: color)
            // Nudged down so the glyph sits on the text's optical centre rather
            // than its baseline, which would ride high against the digits.
            attachment.bounds = CGRect(x: 0, y: -2.5, width: 13, height: 13)
            result.append(NSAttributedString(attachment: attachment))

            result.append(NSAttributedString(
                string: " \(Int(entry.percent.rounded()))",
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
