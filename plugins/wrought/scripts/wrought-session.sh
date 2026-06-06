#!/usr/bin/env bash
# wrought-session.sh — ensure the 'wrought' playwright-cli session exists.
#
# Usage:
#   wrought-session.sh                    # probe → attach --cdp / open --persistent
#   wrought-session.sh --probe-only       # never launch; exit 1 if no session can be established without it
#   wrought-session.sh --managed          # skip the CDP probe; always open --persistent
#   wrought-session.sh --port=9222        # CDP port to probe
#
# Output: a single line of JSON to stdout describing what mode the session is in.
# Human-facing log lines go to stderr.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=$(bash "$SCRIPT_DIR/wrought-root.sh")
PROFILE="$ROOT/chromium-profile"
PROBE_ONLY=false
MANAGED=false
PORT=9222

for arg in "$@"; do
  case "$arg" in
    --probe-only) PROBE_ONLY=true ;;
    --managed) MANAGED=true ;;
    --port=*) PORT="${arg#--port=}" ;;
    *) echo "wrought-session: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v playwright-cli >/dev/null 2>&1; then
  echo "wrought-session: playwright-cli not on PATH." >&2
  echo "  Install with: brew install playwright-cli" >&2
  exit 5
fi

emit_json() {
  printf '%s\n' "$1"
}

# Already-running wrought session? `playwright-cli list` formats entries as
# `- wrought:` so we match on word boundary, not whitespace.
if playwright-cli list 2>/dev/null | grep -qE '\bwrought\b'; then
  echo "wrought-session: existing 'wrought' session found" >&2
  emit_json '{"mode":"existing","session":"wrought"}'
  exit 0
fi

# Probe CDP — attach if alive (unless --managed forces a fresh launch).
if [ "$MANAGED" = false ]; then
  if curl -sf -m 1 "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
    echo "wrought-session: CDP browser detected on localhost:$PORT — attaching" >&2
    if ! playwright-cli -s=wrought attach --cdp "http://localhost:$PORT" >&2; then
      echo "wrought-session: attach --cdp failed; the browser may not be Chromium-family" >&2
      exit 3
    fi
    emit_json "{\"mode\":\"cdp-attached\",\"session\":\"wrought\",\"port\":$PORT}"
    exit 0
  fi
fi

if [ "$PROBE_ONLY" = true ]; then
  echo "wrought-session: no CDP browser on localhost:$PORT and --probe-only was set" >&2
  exit 1
fi

# Launch managed Chrome with a dedicated persistent profile.
echo "wrought-session: launching managed Chrome with profile $PROFILE" >&2
if ! playwright-cli -s=wrought open --browser=chrome --profile="$PROFILE" about:blank >&2; then
  echo "wrought-session: managed launch failed" >&2
  exit 4
fi
emit_json "{\"mode\":\"launched\",\"session\":\"wrought\",\"profile\":\"$PROFILE\"}"
