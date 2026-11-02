#!/bin/bash
# Renders the README screenshots into docs/screenshots/ from Inkflow's demo drawing.
# Demo mode only changes what new documents start with; nothing is saved.
#
#   scripts/screenshots.sh [path/to/Inkflow.app]
#
# Needs Screen Recording permission for your terminal (System Settings > Privacy & Security).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/dd/Build/Products/Debug/Inkflow.app}"
BIN="$APP/Contents/MacOS/Inkflow"
OUT="$ROOT/docs/screenshots"
mkdir -p "$OUT"
[ -x "$BIN" ] || { echo "Build Inkflow first (or pass the path to Inkflow.app): $BIN" >&2; exit 1; }

# shot <name> <app args...>
shot() {
  local name=$1; shift
  pkill -x Inkflow 2>/dev/null || true
  sleep 0.5
  # AppKit reads "-Key value" pairs as defaults, so they go before Inkflow's own options.
  "$BIN" -ApplePersistenceIgnoreState YES "$@" >/dev/null 2>&1 &
  local pid=$!
  disown "$pid"
  sleep "${WAIT:-3}"
  local id
  id=$(swift "$ROOT/scripts/window_ids.swift" "$pid" | awk '{split($3, s, "x"); if (s[1] > 600) {print $1; exit}}')
  if [ -n "$id" ]; then
    screencapture -x -o -l "$id" "$OUT/$name.png"
    echo "  $name.png"
  else
    echo "  $name: no window found" >&2
  fi
  kill "$pid" 2>/dev/null || true
}

echo "Rendering screenshots into docs/screenshots/"
shot light --demo light --appearance light --size 1280x800 --tool brush
shot dark  --demo dark  --appearance dark  --size 1280x800 --tool marker --layers
pkill -x Inkflow 2>/dev/null || true
echo "Done."
