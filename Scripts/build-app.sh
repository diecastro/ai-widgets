#!/usr/bin/env bash
# Builds AIUsage.app with its widget extension.
#
# Supersedes make-app.sh: a WidgetKit extension cannot be built by SwiftPM, and
# the extension is sandboxed, so its App Group entitlement must be signed by a
# real development certificate. A free Apple ID is enough — see README.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-Debug}"
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "error: brew install xcodegen" >&2; exit 1; }
xcodegen generate >/dev/null

ARGS=(-project AIUsage.xcodeproj -scheme AIUsage -configuration "$CONFIG"
      -derivedDataPath .xcbuild)

# DEVELOPMENT_TEAM is what turns the entitlements from a build error into a
# signed app. Without it, build unsigned so the code at least gets compiled.
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
else
  echo "note: no DEVELOPMENT_TEAM set — building unsigned."
  echo "      The widget will NOT load; the sandbox denies the App Group without"
  echo "      a signed entitlement. See README 'Running the widget'."
  ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
         CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS="")
fi

xcodebuild "${ARGS[@]}" build

APP="$ROOT/.xcbuild/Build/Products/$CONFIG/AIUsage.app"
echo
echo "built $APP"
echo "run:  open \"$APP\""
