#!/usr/bin/env bash
# Idempotently set up the wrought data root.
# Safe to run on every invocation — fast no-op when already initialised.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=$(bash "$SCRIPT_DIR/wrought-root.sh")

mkdir -p \
  "$ROOT" \
  "$ROOT/scratch" \
  "$ROOT/staged" \
  "$ROOT/library" \
  "$ROOT/broken" \
  "$ROOT/sessions" \
  "$ROOT/chromium-profile"

# stats.json — per-snippet metadata
if [ ! -f "$ROOT/stats.json" ]; then
  echo '{}' > "$ROOT/stats.json"
fi

# INDEX.md — retrieval surface
if [ ! -f "$ROOT/INDEX.md" ]; then
  cat > "$ROOT/INDEX.md" <<'EOF'
# Wrought snippet index

Auto-generated. Do not edit by hand — `wrought-registry.mjs reindex` regenerates this file.

No snippets yet.
EOF
fi

# Required external tool: playwright-cli. We don't install it — surface the requirement clearly.
if ! command -v playwright-cli >/dev/null 2>&1; then
  echo "wrought: playwright-cli is not installed." >&2
  echo "  Install with: brew install playwright-cli" >&2
  echo "  (wrought wraps playwright-cli; it cannot drive a browser without it)" >&2
  exit 5
fi

# Emit KEY=VALUE lines for downstream consumers.
printf 'WROUGHT_ROOT=%s\n' "$ROOT"
printf 'WROUGHT_PROFILE=%s\n' "$ROOT/chromium-profile"
printf 'WROUGHT_SESSION=%s\n' 'wrought'
printf 'PLAYWRIGHT_CLI=%s\n' "$(command -v playwright-cli)"
