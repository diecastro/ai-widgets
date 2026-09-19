# AI Usage

A macOS menu bar app (and, once Xcode is set up, a Notification Center widget)
showing how close you are to the rate limits of the AI coding tools you use.

Quota percentages only — no token counts, no cost tracking.

## Status

| Milestone | State |
|---|---|
| M1 Model + Claude Code provider | done |
| M2 Codex provider | done |
| M3 Snapshot store + refresher | done |
| M4 Menu bar app | done |
| M5 WidgetKit extension | built; needs a signing identity to run |
| M6 Cursor provider | needs a credential |
| M7 Preferences, launch at login | not started |

## Quick start

```sh
./Scripts/install-claude-hook.sh   # once, so Claude Code caches its quota
./Scripts/build-app.sh             # app + widget extension (needs xcodegen)
open .xcbuild/Build/Products/Debug/AIUsage.app
```

`Scripts/make-app.sh` still builds a menu-bar-only app straight from SwiftPM,
with no Xcode and no signing. Use it if you only want the menu bar.

## Running the widget

The menu bar app is not sandboxed, so it reads `~/.claude` and `~/.codex`
directly. **A widget extension is always sandboxed**, and can reach the shared
App Group container only if its entitlement is signed by a real development
certificate. There is no way around this: App Groups are the only channel macOS
offers between an app and its widget.

A **free** Apple ID is sufficient — no paid developer account.

1. Xcode → Settings → Accounts → **+** → Apple ID, and sign in.
2. Find the resulting team id:
   `security find-identity -v -p codesigning` (the parenthesised 10-character code).
3. Build with it:
   ```sh
   DEVELOPMENT_TEAM=XXXXXXXXXX ./Scripts/build-app.sh
   open .xcbuild/Build/Products/Debug/AIUsage.app
   ```
4. Right-click the desktop → Edit Widgets → **AI Usage**.

Without `DEVELOPMENT_TEAM` the script still builds, but unsigned: the code
compiles and the menu bar works, while the widget will not load.

`./.build/debug/usage-probe` prints the same data as plain text, which is the
fastest way to check ingest is working.

## Where the numbers come from

**Claude Code** only exposes live quota through the JSON it hands its statusline
command — session transcripts contain it only on a 429 rejection.
`Scripts/install-claude-hook.sh` appends a small block to your existing
`~/.claude/statusline-command.sh` that caches those numbers to
`~/.ai-usage/claude.json`. The block backs up your script first, never changes
what the statusline prints, swallows every error, and is removed with
`--uninstall`.

**Codex** writes rate limits straight into its session rollouts under
`~/.codex/sessions`, so no setup is needed.

**Cursor** has no local data and needs a credential; not implemented yet.

## How staleness is handled

Both sources only update while a CLI session is running, so a reading can be
hours old. Rather than decay or interpolate a number it cannot know, the app
shows its confidence:

- **fresh** — sampled within the last 6 hours.
- **stale** — older, but the window has not reset, so the value is a floor.
- **reset** — `resetsAt` has passed, so the window genuinely restarted and the
  displayed value is `0%`. This is the one case where a current value can be
  asserted without a fresh sample.

## Layout

- `Sources/UsageCore` — model, providers, store. No UI, no AppKit.
- `Sources/AIUsageMenuBar` — the status item, popover, and file watching.
- `Sources/usage-probe` — diagnostic CLI.
- `Tests/UsageCoreTests` — Swift Testing, against fixtures captured from real data.

Collection lives entirely in the app. WidgetKit extensions are always sandboxed
and cannot read `~/.claude` or `~/.codex`, so the widget will only ever read the
snapshot the app writes to the shared App Group container.

## Tests

`swift test` requires Xcode — Command Line Tools ship `Testing.framework` but not
the `_TestingInternals` module it is built against.
