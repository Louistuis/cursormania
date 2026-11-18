#!/bin/bash
# Screenshot the real app window without it ever appearing on screen.
# usage: Tools/shot.sh out.png [--theme id] [--width w --height h]
set -euo pipefail
OUT="$1"; shift
BIN="$(cd "$(dirname "$0")/.." && pwd)/build/CursorMania.app/Contents/MacOS/CursorMania"
FIFO="$(mktemp)"
"$BIN" --shot-window "$@" --hold 5 > "$FIFO" &
PID=$!
for _ in $(seq 1 40); do [ -s "$FIFO" ] && break; sleep 0.1; done
sleep 2.2
ID="$(head -1 "$FIFO")"
screencapture -x -l "$ID" "$OUT"
kill "$PID" 2>/dev/null || true
rm -f "$FIFO"
echo "$OUT"
