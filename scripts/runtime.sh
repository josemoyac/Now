#!/bin/sh
# Optional bootstrap for this Mac; regular installations simply use npm or pnpm.
NOW_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -x "$NOW_ROOT/.local/runtime/node-v24.21.0-darwin-arm64/bin/node" ]; then
  export PATH="$NOW_ROOT/.local/runtime/node-v24.21.0-darwin-arm64/bin:$PATH"
elif ! command -v node >/dev/null 2>&1; then
  export PATH="/Applications/Codex.app/Contents/Resources/cua_node/bin:$PATH"
fi
exec "$@"
