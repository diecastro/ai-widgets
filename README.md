# AI Usage

A macOS menu bar app and Notification Center widget showing how close you are to
the rate limits of the AI coding tools you use.

Quota percentages only — no token counts, no cost tracking. The question it
answers is "can I keep working, and on which tool?"

## Status

| Milestone | State |
|---|---|
| M1 Model + Claude Code provider | done |
| M2 Codex provider | done |
| M3 Snapshot store + refresher | done |
| M4 Menu bar app | done |
| M5 WidgetKit extension | done |
| M6 Cursor provider | needs a credential |
| M7 Preferences, launch at login | not started |

## Quick start

```sh
./Scripts/install-claude-hook.sh                  # once, so Claude Code caches its quota
DEVELOPMENT_TEAM=XXXXXXXXXX ./Scripts/build-app.sh # see Signing
cp -R .xcbuild/Build/Products/Debug/AIUsage.app /Applications/
open /Applications/AIUsage.app
```

Then right-click the desktop → **Edit Widgets** → **AI Usage**.

Install to `/Applications` rather than running from `.xcbuild`: widget discovery
is unreliable for an app under a build directory, and the registration breaks
whenever that path is rebuilt.

`./.build/debug/usage-probe` prints the same data as plain text and is the
fastest way to check ingest, with no app and no signing.

`Scripts/make-app.sh` builds a menu-bar-only app straight from SwiftPM — no
Xcode, no signing, no widget. Use it if the menu bar is all you want.

## What it shows

The menu bar lists every provider that has data, as its mark plus a percentage,
tinted green / orange / red at 50% and 80%. Clicking opens a panel with each
window, a reset countdown and how old the reading is.

The **small** widget shows the session (5-hour) window only — at that size the
question is whether you can keep working right now. The **medium** widget shows
every window, since it has room for the session/weekly split that actually
changes a decision.

## Signing

The widget needs a development certificate: a widget extension is always
sandboxed, and macOS will not register an unsandboxed one at all.

A **free** Apple ID is enough. Xcode → Settings → Accounts → **+**, sign in,
then take the team id from the `OU` field:

```sh
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

Pass it as `DEVELOPMENT_TEAM`. Without it `build-app.sh` still builds, unsigned:
the code compiles and the menu bar runs, but the widget will not load.

Note that `security find-identity -v -p codesigning` may report *"0 valid
identities"* for a perfectly usable certificate. Check `-p codesigning` without
`-v`; if the identity is listed as matching, it will sign.

## How the widget gets its data

The app is not sandboxed, so it reads `~/.claude` and `~/.codex` directly. The
widget is sandboxed and can read neither. All collection therefore happens in the
app, which writes one snapshot that the widget only reads.

The sanctioned channel for that is an App Group — but the capability has to be
granted on the App ID, and **a free Apple Developer team cannot grant it**. The
entitlement still signs, the profile comes back with no groups, macOS silently
ignores it at runtime, and the widget renders "No data yet" with nothing to
indicate why.

So the app also writes into the widget's own sandbox container, which works
because the app is unsandboxed and a sandboxed process can always read its own
home. `SnapshotStore` writes every sink it can reach and reads the first that
answers, still preferring a real App Group where one is provisioned:

| Sink | Written by | Read by |
|---|---|---|
| App Group container | app, when provisioned | widget, when provisioned |
| `~/Library/Containers/<widget id>/Data/snapshot.json` | app | widget (its own home) |
| `~/.ai-usage/snapshot.json` | app | `usage-probe` |

## Where the numbers come from

**Claude Code** exposes live quota in exactly one place: the JSON it pipes to its
statusline command. Session transcripts carry it only on a 429 rejection, so they
are not a usable source. `Scripts/install-claude-hook.sh` appends a small block to
your existing `~/.claude/statusline-command.sh` that caches those numbers to
`~/.ai-usage/claude.json`. The block backs your script up first, never changes
what the statusline prints, swallows every error, and is removed with
`--uninstall`.

**Codex** writes rate limits straight into its session rollouts under
`~/.codex/sessions`, so it needs no setup.

**Cursor** has no local data and needs a credential; not implemented.

## How staleness is handled

Both sources only update while a CLI session is running, so a reading can be
hours old. Rather than decay or interpolate a number it cannot know, each surface
shows its confidence:

- **fresh** — sampled within the last 6 hours.
- **stale** — older, but the window has not reset, so the value is a floor.
- **reset** — `resetsAt` has passed, so the window genuinely restarted and the
  displayed value is `0%`. This is the one case where a current value can be
  asserted without a fresh sample.

## Layout

- `Sources/UsageCore` — model, providers, store. No UI, no AppKit.
- `Sources/AIUsageMenuBar` — status item, popover, file watching. Does all collection.
- `Sources/AIUsageWidget` — renders only; never reads the home directory.
- `Sources/usage-probe` — diagnostic CLI.
- `Tests/UsageCoreTests` — Swift Testing, against fixtures captured from real data.

`project.yml` is the source of truth for the Xcode project; `AIUsage.xcodeproj`,
`Support/` and `.xcbuild/` are generated and git-ignored. Run `xcodegen generate`
rather than editing the `.pbxproj`. `Package.swift` still owns UsageCore, the
tests and `usage-probe`.

## Tests

```sh
swift test                            # 32 tests
swift test --filter 'newest rollout'  # one, by a fragment of its name
```

Requires Xcode: Command Line Tools ship `Testing.framework` but not the
`_TestingInternals` module it is built against.
