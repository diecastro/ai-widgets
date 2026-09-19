import AppKit
import SwiftUI
import UsageCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var model: UsageModel!
    private var watcher: SourceWatcher?
    private var pollTimer: Timer?
    private var clockTimer: Timer?

    /// A safety net behind the file watcher, not the primary refresh path.
    private let pollInterval: TimeInterval = 60
    /// Keeps countdowns honest and flips a passed reset to 0% on time.
    private let clockInterval: TimeInterval = 30

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = UsageModel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        // Respond to either button, since a menu bar item with no menu should
        // still open on a right-click rather than doing nothing.
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model) { NSApp.terminate(nil) })

        watchSources()
        schedule()
        Task { await refreshAndRender() }
    }

    private func watchSources() {
        watcher = SourceWatcher(paths: [
            ClaudeCodeProvider.defaultCacheURL,
            CodexProvider.defaultSessionsRoot
        ]) { [weak self] in
            Task { await self?.refreshAndRender() }
        }
    }

    private func schedule() {
        pollTimer = .scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in await self?.refreshAndRender() }
        }
        clockTimer = .scheduledTimer(withTimeInterval: clockInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.model.tick()
                self?.render()
            }
        }
    }

    private func refreshAndRender() async {
        await model.refresh()
        render()
    }

    private func render() {
        statusItem.button?.attributedTitle =
            MenuBarLabel.attributedTitle(for: model.snapshot, now: model.now)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh on open so the popover never shows a number older than the click.
            Task { await refreshAndRender() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
