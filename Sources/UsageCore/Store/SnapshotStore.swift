import Foundation
import os

/// The one channel between collection and display.
///
/// WidgetKit extensions are always sandboxed, so the widget cannot read
/// `~/.claude` or `~/.codex` itself. The app collects, writes here, and the
/// widget only reads. Writes go to a temp file and are renamed into place, so a
/// reader never observes a half-written snapshot.
public struct SnapshotStore: Sendable {
    public static let appGroupID = "group.com.aiusage.widget"

    private let fileURL: URL
    private static let log = Logger(subsystem: "com.aiusage", category: "store")

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The shared container when the App Group is provisioned, falling back to
    /// `~/.ai-usage` so the app and the CLI still work unsandboxed during development.
    public init(appGroupID: String = SnapshotStore.appGroupID) {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let directory = container ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".ai-usage")
        if container == nil {
            Self.log.notice("App Group \(appGroupID) unavailable; using \(directory.path)")
        }
        self.init(fileURL: directory.appendingPathComponent("snapshot.json"))
    }

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

    public func write(_ snapshot: UsageSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".snapshot-\(UUID().uuidString).tmp")
        try Self.encoder.encode(snapshot).write(to: temp)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
    }

    /// Returns ``UsageSnapshot/empty`` rather than throwing when nothing has been
    /// written yet — a widget's first render is a normal state, not a failure.
    public func read() -> UsageSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? Self.decoder.decode(UsageSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
