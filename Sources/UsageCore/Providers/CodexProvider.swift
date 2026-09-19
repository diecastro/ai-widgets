import Foundation

/// Reads the newest Codex session rollout.
///
/// Codex writes `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, and its
/// `token_count` events embed `rate_limits.primary` / `.secondary` with
/// `used_percent`, `window_minutes` and `resets_at`. Windows are labelled from
/// `window_minutes` rather than from the `primary`/`secondary` position, so a
/// change to Codex's window scheme degrades to ``WindowKind/other(minutes:)``
/// instead of mislabelling a reading.
public struct CodexProvider: UsageProvider {
    public let id = ProviderID.codex
    private let sessionsRoot: URL

    public static let defaultSessionsRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/sessions")

    public init(sessionsRoot: URL = CodexProvider.defaultSessionsRoot) {
        self.sessionsRoot = sessionsRoot
    }

    public func fetch() async throws -> ProviderSnapshot {
        guard let newest = Self.newestRollout(under: sessionsRoot) else {
            throw ProviderError.noData("no rollout files under \(sessionsRoot.path)")
        }
        guard let data = try? Data(contentsOf: newest) else {
            throw ProviderError.unreadable("could not read \(newest.lastPathComponent)")
        }
        return try Self.parse(data)
    }

    /// Most recently modified `rollout-*.jsonl`, wherever it sits in the date tree.
    static func newestRollout(under root: URL) -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return nil }

        var newest: (url: URL, modified: Date)?
        for case let url as URL in walker {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            if newest == nil || modified > newest!.modified {
                newest = (url, modified)
            }
        }
        return newest?.url
    }

    /// Pure: scans backwards for the last `token_count` event carrying rate limits.
    ///
    /// Reading in reverse matters — a long session holds hundreds of events and
    /// only the final one reflects current quota.
    public static func parse(_ data: Data) throws -> ProviderSnapshot {
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)

        for line in lines.reversed() {
            guard let event = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let payload = event["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let limits = payload["rate_limits"] as? [String: Any]
            else { continue }

            let windows = ["primary", "secondary"].compactMap { key -> QuotaWindow? in
                guard let entry = limits[key] as? [String: Any],
                      let used = entry["used_percent"] as? Double,
                      let minutes = entry["window_minutes"] as? Int else { return nil }
                let resets = (entry["resets_at"] as? Double).map(Date.init(timeIntervalSince1970:))
                return QuotaWindow(kind: WindowKind(windowMinutes: minutes),
                                   usedPercent: used,
                                   resetsAt: resets)
            }
            guard !windows.isEmpty else { continue }

            let observedAt = (event["timestamp"] as? String).flatMap(Self.timestamp(from:)) ?? Date()
            return ProviderSnapshot(provider: .codex, windows: windows, observedAt: observedAt)
        }

        throw ProviderError.noData("no token_count event with rate_limits")
    }

    /// `Date.ISO8601FormatStyle` is a `Sendable` value type, unlike the cached
    /// `ISO8601DateFormatter` a shared static would otherwise need.
    private static func timestamp(from string: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return (try? fractional.parse(string)) ?? (try? Date.ISO8601FormatStyle().parse(string))
    }
}
