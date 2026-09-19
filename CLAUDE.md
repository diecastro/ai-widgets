# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS menu bar app and WidgetKit widget showing how close you are to the rate
limits of Claude Code, Codex, and (not yet built) Cursor. Quota percentages only
— deliberately no token counts and no cost tracking.

## Commands

```sh
xcodegen generate                        # regenerate AIUsage.xcodeproj from project.yml
./Scripts/build-app.sh                   # app + widget extension (see signing, below)
swift build                              # UsageCore, usage-probe (no Xcode project needed)
swift test                               # 27 tests, Swift Testing
swift test --filter 'newest rollout'     # one test, by a fragment of its name

./Scripts/make-app.sh                    # menu-bar-only app, SwiftPM, no signing
pkill -f AIUsage.app                     # stop a running app

./.build/debug/usage-probe               # print live quota as text
./.build/debug/usage-probe <fixture-dir> # same, against fixtures

./Scripts/install-claude-hook.sh             # enable Claude Code ingest (once)
./Scripts/install-claude-hook.sh --uninstall # remove it
```

Test names use raw identifiers (`` @Test func `reads both windows`() ``), so
`--filter` takes a fragment of the prose name.

## Toolchain

`swift test` **requires Xcode**. Command Line Tools ship `Testing.framework` but
not the `_TestingInternals` module it is built against, so the test target cannot
compile against CLT alone. Everything else builds fine on CLT.

`usage-probe` exists to verify ingest when tests cannot run. If Xcode's license
has not been accepted, `export DEVELOPER_DIR=/Library/Developer/CommandLineTools`
falls back to CLT for builds.

## The Xcode project is generated

`project.yml` is the source of truth; `AIUsage.xcodeproj`, `Support/` and
`.xcbuild/` are all generated and git-ignored. **Never hand-edit the
`.pbxproj`** — run `xcodegen generate`. `Package.swift` still owns UsageCore,
the tests and `usage-probe`; the Xcode project exists only because SwiftPM
cannot build a WidgetKit extension.

## Signing

The widget needs a real development certificate. Its App Group entitlement is
the only channel macOS offers between an app and its widget, and a sandboxed
extension only gets it when the entitlement is signed. A free Apple ID in
Xcode → Settings → Accounts is enough; then build with
`DEVELOPMENT_TEAM=XXXXXXXXXX ./Scripts/build-app.sh`.

Without it `build-app.sh` falls back to an unsigned build, which compiles and
runs the menu bar but will not load the widget. If the build fails with
"has entitlements that require signing with a development certificate", that is
this, not a project misconfiguration.

## Architecture

```
UsageCore        model + providers + store. No AppKit, no SwiftUI.
AIUsageMenuBar   status item, popover, file watching. Does all collection.
AIUsageWidget    renders only. Never reads the home directory.
usage-probe      diagnostic CLI over UsageCore.
```

### The sandbox boundary — the most important constraint

WidgetKit extensions are **always sandboxed** and cannot read `~/.claude` or
`~/.codex`. So collection lives entirely in the app, which writes one snapshot to
the App Group container (`group.com.diecastro.aiusage`); the widget only ever reads
that. `SnapshotStore` is the sole channel between the two, and falls back to
`~/.ai-usage/snapshot.json` when the App Group is unavailable.

Do not add filesystem or network reads to `AIUsageWidget`.

### Where the numbers come from

**Claude Code exposes live quota in exactly one place: the JSON it pipes to its
statusline command** (`rate_limits.five_hour` / `.seven_day`). Session transcripts
under `~/.claude/projects` contain quota data *only* on a 429 rejection, so they
are not a usable source — do not be tempted to parse them.

`Scripts/install-claude-hook.sh` therefore appends a guarded block to the user's
own `~/.claude/statusline-command.sh` that caches that JSON to
`~/.ai-usage/claude.json`, and `ClaudeCodeProvider` reads only that file. That
script edits a file outside the repo, so it must keep backing up first, stay
idempotent, never change what the statusline prints, and swallow every error.

**Codex** embeds `rate_limits` directly in `token_count` events inside
`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. `CodexProvider` takes the newest
rollout by mtime and scans it **backwards**, since only the last such event
reflects current quota.

### Freshness — the rule that drives most of the display code

Both sources only update while a CLI session runs, so a reading may be hours old.
The code never decays or interpolates a value it cannot know. Instead:

- `QuotaWindow.usedPercent` is the raw sample and is preserved.
- `effectiveUsedPercent(asOf:)` is what gets displayed, and returns **0 once
  `resetsAt` has passed** — the one case where a current value can be asserted
  without a fresh sample.
- `Freshness` classifies a reading as `.fresh`, `.stale` (>6h, window still
  standing) or `.reset`, and every surface renders that alongside the number.

Tests that assert "most constrained window" must pin an explicit `now`; asserting
against `Date()` is how they break, because fixture reset times drift into the past.

### Adding a provider

Implement `UsageProvider` (one file), take the source location by injection, and
keep parsing in a `static` pure function so it can be tested against a fixture
with no app and no network. Add the case to `ProviderID`. Nothing else changes —
`UsageRefresher` fans out with a task group and drops providers that fail, since
"Codex hasn't run today" is the normal case, not an error.

Label quota windows from their **length in minutes**, never from a `primary` /
`secondary` position, so an upstream change degrades to `WindowKind.other`
instead of mislabelling a reading.

## Conventions

Swift 6.2 concurrency: the app target is main-actor-by-default via
`.defaultIsolation(MainActor.self)`; `UsageCore` deliberately is not, so callers
decide where work runs. Follow the `write-swift` skill in `.agents/skills/` —
value types by default, and when a data-race error appears, stop sharing the
object rather than reaching for `@unchecked Sendable`.

`Scripts/make-app.sh` hand-assembles the `.app` because SwiftPM cannot produce
the `LSUIElement` bundle a menu bar agent needs. Once an `.xcodeproj` exists
(needed for the widget extension and the App Group entitlement), it supersedes
this script.

Menu bar marks are drawn as vectors in `ProviderGlyph`, not shipped app icons: a
colour icon cannot take the severity tint, does not invert between light and dark
menu bars, and loses its detail at 13pt — and Codex ships no artwork at all. Ray
widths are **absolute, not angular**; an angular wedge converges to nothing at the
hub and renders as hairlines that vanish at menu bar size. When changing a glyph,
render it to a PNG and look at it at 13px before committing.

Severity thresholds live in one place (`UsageStyle`): caution at 50%, critical at 80%.
