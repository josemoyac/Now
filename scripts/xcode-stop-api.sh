#!/bin/sh
set -eu
NOW_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NOW_PID="$NOW_ROOT/.local/xcode-api.pid"
if [ -f "$NOW_PID" ]; then
  kill "$(cat "$NOW_PID")" 2>/dev/null || true
  rm -f "$NOW_PID"
fi
