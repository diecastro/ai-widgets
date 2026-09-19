import Foundation

/// Reads the cache file written by the Claude Code statusline hook.
///
/// Claude Code hands its statusline command a JSON blob on stdin containing
/// `rate_limits.five_hour` / `.seven_day`. That is the only live source of quota
/// data — session transcripts carry it only on a 429 rejection. `Scripts/install-claude-hook.sh`
/// appends a write of that blob to the user's statusline script; this provider
/// reads the result and never touches `~/.claude` itself.
public struct ClaudeCodeProvider: UsageProvider {
    public let id = ProviderID.claudeCode
    private let cacheURL: URL

    public static let defaultCacheURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".ai-usage/claude.json")

    public init(cacheURL: URL = ClaudeCodeProvider.defaultCacheURL) {
        self.cacheURL = cacheURL
    }

    public func fetch() async throws -> ProviderSnapshot {
        guard let data = try? Data(contentsOf: cacheURL) else {
            throw ProviderError.noData("no statusline cache at \(cacheURL.path)")
        }
        return try Self.parse(data)
    }

    /// Pure, so it can be tested against a fixture without touching the filesystem.
    public static func parse(_ data: Data) throws -> ProviderSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.unreadable("claude cache is not JSON")
        }
        let observedAt = (root["observed_at"] as? Double).map(Date.init(timeIntervalSince1970:))
            ?? Date()
        let limits = root["rate_limits"] as? [String: Any] ?? [:]

        let windows = [("five_hour", WindowKind.fiveHour),
                       ("seven_day", .weekly),
                       ("spend_limit", .spendLimit)]
            .compactMap { key, kind -> QuotaWindow? in
                guard let entry = limits[key] as? [String: Any],
                      let used = entry["used_percentage"] as? Double else { return nil }
                let resets = (entry["resets_at"] as? Double).map(Date.init(timeIntervalSince1970:))
                return QuotaWindow(kind: kind, usedPercent: used, resetsAt: resets)
            }

        return ProviderSnapshot(provider: .claudeCode, windows: windows, observedAt: observedAt)
    }
}
