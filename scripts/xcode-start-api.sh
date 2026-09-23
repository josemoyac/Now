#!/bin/sh
set -eu

NOW_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NOW_HEALTH="http://127.0.0.1:4000/health"
NOW_STATE="$NOW_ROOT/.local"
NOW_LOG="$NOW_STATE/xcode-api.log"
NOW_PID="$NOW_STATE/xcode-api.pid"

# Archive/Profile use the configured production API and must not launch local services.
# Build-only validation can explicitly skip a local listener in restricted CI sandboxes.
if [ "${NOW_SKIP_LOCAL_API:-0}" = "1" ]; then
  exit 0
fi

if [ "${CONFIGURATION:-Debug}" = "Release" ]; then
  exit 0
fi

if /usr/bin/curl --silent --fail --max-time 1 "$NOW_HEALTH" >/dev/null 2>&1; then
  echo "NOW API ya está disponible en 127.0.0.1:4000"
  exit 0
fi

mkdir -p "$NOW_STATE"
# tsx starts a small IPC socket inside os.tmpdir(); keep it in the project's writable runtime area when Xcode launches us.
export TMPDIR="$NOW_STATE/tmp"
mkdir -p "$TMPDIR"
if [ ! -d "$NOW_ROOT/node_modules" ]; then
  echo "Faltan las dependencias. Ejecuta una vez: ./scripts/runtime.sh npm install" >&2
  exit 1
fi

cd "$NOW_ROOT"
export DEMO_MODE=true
export DATABASE_URL="pglite://.local/postgres"
export HOST="127.0.0.1"
export PORT="4000"

./scripts/runtime.sh node --import tsx db/migrate.ts >>"$NOW_LOG" 2>&1
./scripts/runtime.sh node --import tsx db/seed.ts >>"$NOW_LOG" 2>&1
nohup ./scripts/runtime.sh node --import tsx apps/api/src/main.ts >>"$NOW_LOG" 2>&1 &
echo $! >"$NOW_PID"

NOW_ATTEMPT=0
while [ "$NOW_ATTEMPT" -lt 40 ]; do
  if /usr/bin/curl --silent --fail --max-time 1 "$NOW_HEALTH" >/dev/null 2>&1; then
    echo "NOW API demo iniciada en 127.0.0.1:4000"
    exit 0
  fi
  NOW_ATTEMPT=$((NOW_ATTEMPT + 1))
  sleep 0.25
done

echo "La API no arrancó. Revisa $NOW_LOG" >&2
exit 1
