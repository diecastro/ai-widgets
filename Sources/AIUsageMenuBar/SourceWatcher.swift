import Foundation
import os

/// Fires when a watched path changes, so the menu bar updates the moment a CLI
/// session writes new numbers instead of waiting for the next poll.
///
/// Editors and atomic writers replace files rather than mutating them, so the
/// watch is re-established on `.delete` and `.rename` — without that, a single
/// atomic write would silently end the watch.
@MainActor
final class SourceWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var descriptors: [Int32] = []
    private let paths: [URL]
    private let onChange: () -> Void
    private static let log = Logger(subsystem: "com.aiusage", category: "watch")

    init(paths: [URL], onChange: @escaping () -> Void) {
        self.paths = paths
        self.onChange = onChange
        for path in paths { watch(path) }
    }

    private func watch(_ url: URL) {
        // Watch the containing directory when the file itself is absent, so the
        // first write is noticed too.
        let target = FileManager.default.fileExists(atPath: url.path)
            ? url : url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: target.path) else { return }

        let descriptor = open(target.path, O_EVTONLY)
        guard descriptor >= 0 else {
            Self.log.debug("could not watch \(target.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main)

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            self.onChange()
            if events.contains(.delete) || events.contains(.rename) {
                source.cancel()
                // The path was replaced; re-establish against the new inode.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.watch(url)
                }
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()

        sources.append(source)
        descriptors.append(descriptor)
    }

    deinit {
        for source in sources { source.cancel() }
    }
}
