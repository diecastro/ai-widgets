#!/usr/bin/env bash
# Teaches the Claude Code statusline to cache its rate-limit numbers for the
# AI Usage widget.
#
# Claude Code hands its statusline command a JSON blob on stdin containing
# rate_limits.five_hour / .seven_day. That is the only live source of quota data,
# so the widget gets it by appending a cache write to the end of the user's
# existing statusline script. The appended block:
#
#   * never changes what the statusline prints,
#   * can never fail the statusline (all errors swallowed),
#   * writes atomically via temp-file + rename,
#   * is idempotent (re-running replaces the block rather than stacking copies).
#
# Undo with --uninstall, or just delete the marked block by hand.

set -euo pipefail

STATUSLINE="${CLAUDE_STATUSLINE:-$HOME/.claude/statusline-command.sh}"
CACHE_DIR="$HOME/.ai-usage"
BEGIN="# >>> ai-usage widget cache >>>"
END="# <<< ai-usage widget cache <<<"

strip_block() {  # print $1 with any previously installed block removed
  # Blank lines are buffered and only emitted once real content follows, so the
  # blank line that separates the block never survives as trailing whitespace.
  # Without this, repeated install/uninstall cycles would grow the file.
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skipping = 1 }
    !skipping {
      if ($0 == "") { pending = pending "\n"; next }
      printf "%s%s\n", pending, $0; pending = ""
    }
    $0 == e { skipping = 0 }
  ' "$1"
}

if [ "${1:-}" = "--uninstall" ]; then
  [ -f "$STATUSLINE" ] || { echo "no statusline at $STATUSLINE"; exit 0; }
  strip_block "$STATUSLINE" > "$STATUSLINE.tmp" && mv "$STATUSLINE.tmp" "$STATUSLINE"
  chmod +x "$STATUSLINE"
  echo "removed the cache block from $STATUSLINE"
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

if [ ! -f "$STATUSLINE" ]; then
  echo "error: no statusline script at $STATUSLINE" >&2
  echo "       set statusLine.command in ~/.claude/settings.json first," >&2
  echo "       or point this script at yours with CLAUDE_STATUSLINE=/path" >&2
  exit 1
fi

# The statusline reads stdin once into a variable; appending a second read would
# get nothing. Bail out rather than install a block that silently never fires.
if ! grep -qE '^[[:space:]]*(input|INPUT)=\$\(cat\)' "$STATUSLINE"; then
  echo "error: $STATUSLINE does not capture stdin as \$input" >&2
  echo "       the cache block reuses that variable; adapt it by hand" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

BACKUP="$STATUSLINE.bak.$(date +%Y%m%d%H%M%S)"
cp "$STATUSLINE" "$BACKUP"

{
  strip_block "$STATUSLINE"
  cat <<'BLOCK'

# >>> ai-usage widget cache >>>
# Caches rate-limit percentages for the AI Usage widget. Output is unchanged;
# every failure is swallowed so this can never break the status line.
{
  printf '%s' "$input" \
    | jq -c '{observed_at: now, rate_limits: (.rate_limits // {})}' \
    > "$HOME/.ai-usage/claude.json.tmp" \
    && mv -f "$HOME/.ai-usage/claude.json.tmp" "$HOME/.ai-usage/claude.json"
} >/dev/null 2>&1 || true
# <<< ai-usage widget cache <<<
BLOCK
} > "$STATUSLINE.new"

mv "$STATUSLINE.new" "$STATUSLINE"
chmod +x "$STATUSLINE"

echo "installed the cache block in $STATUSLINE"
echo "backup: $BACKUP"
echo "cache:  $CACHE_DIR/claude.json (appears after the next statusline render)"
