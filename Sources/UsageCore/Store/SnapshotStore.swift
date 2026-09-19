import Foundation
import os

/// The one channel between collection and display.
///
/// A widget extension is always sandboxed — macOS refuses to register one that
/// is not — so it cannot read `~/.claude` or `~/.codex`. The app collects, writes
/// here, and the widget only reads.
///
/// The sanctioned channel is an App Group, but that capability has to be granted
/// on the App ID, and a free Apple Developer team cannot grant it: the profile
/// comes back with no groups and macOS then ignores the entitlement at runtime,
/// leaving the widget silently empty. So the store writes to the widget's *own*
/// sandbox container as well, which works because the app is not sandboxed and
/// a sandboxed process can always read its own home. The App Group is still
/// preferred when it is genuinely provisioned.
public struct SnapshotStore: Sendable {
    public static let appGroupID = "group.com.diecastro.aiusage"
    public static let widgetBundleID = "com.diecastro.aiusage.widget"

    /// Every location a reader might look, in preference order.
    private(set) var candidates: [URL]
    private static let log = Logger(subsystem: "com.aiusage", category: "store")

    public init(fileURL: URL) {
        self.candidates = [fileURL]
    }

    private init(candidates: [URL]) {
        self.candidates = candidates
    }

    // MARK: - Roles

    /// Used by the app: writes to every sink a reader might use.
    public static func collector() -> SnapshotStore {
        var urls: [URL] = []
        if let group = appGroupContainer() {
            urls.append(group.appendingPathComponent("snapshot.json"))
        }
        // The widget's container, reachable only because the app is unsandboxed.
        // Written only when it already exists — creating it by hand would put a
        // directory where the sandbox expects to build its own.
        let widgetData = widgetContainerData()
        if FileManager.default.fileExists(atPath: widgetData.path) {
            urls.append(widgetData.appendingPathComponent("snapshot.json"))
        }
        urls.append(fallbackDirectory().appendingPathComponent("snapshot.json"))
        return SnapshotStore(candidates: urls)
    }

    /// Used by the widget: its own home first, since that is the sink guaranteed
    /// to be readable without an App Group.
    public static func reader() -> SnapshotStore {
        var urls = [URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("snapshot.json")]
        if let group = appGroupContainer() {
            urls.append(group.appendingPathComponent("snapshot.json"))
        }
        urls.append(fallbackDirectory().appendingPathComponent("snapshot.json"))
        return SnapshotStore(candidates: urls)
    }

    // MARK: - Locations

    private static func appGroupContainer() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func widgetContainerData() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data")
    }

    private static func fallbackDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ai-usage")
    }

    // MARK: - I/O

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    /// Writes every candidate. Succeeds if any one does — a sink that is not
    /// provisioned on this machine must not fail the others.
    public func write(_ snapshot: UsageSnapshot) throws {
        let data = try Self.encoder.encode(snapshot)
        var lastError: Error?
        var wrote = false

        for url in candidates {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                // .atomic writes a sibling temp file and renames it, so a reader
                // never sees a half-written snapshot — and unlike replaceItemAt
                // it also works on the first write.
                try data.write(to: url, options: .atomic)
                wrote = true
            } catch {
                lastError = error
                Self.log.debug("could not write \(url.path): \(error)")
            }
        }

        if !wrote, let lastError { throw lastError }
    }

    /// Returns ``UsageSnapshot/empty`` rather than throwing when nothing has been
    /// written yet — a widget's first render is a normal state, not a failure.
    public func read() -> UsageSnapshot {
        for url in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let snapshot = try? Self.decoder.decode(UsageSnapshot.self, from: data) else {
                Self.log.error("undecodable snapshot at \(url.path)")
                continue
            }
            return snapshot
        }
        return .empty
    }
}
