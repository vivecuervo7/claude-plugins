#!/usr/bin/env bash
# Single source of truth for background auto-journaling readiness. Consumed by
# the background auto-journal template (to decide background vs foreground) and
# by `/journal doctor` (to explain the state).
#
# Emits KEY=VALUE lines on stdout:
#   BACKGROUND_READY=true|false   (always exactly one)
#   REASON=<text>                 (only when disabled)
#   MISSING=<rule>                (one per missing allow rule, when enabled but not ready)
#
# Always exits 0 — this is an informational check, never a gate that can itself
# fail the journaling flow.
#
# Usage: journal-ready.sh [settings-json-path]
#   With no arg, reads ~/.claude/settings.json and ~/.claude/settings.local.json
#   (a rule counts as present if it appears in either). An explicit path
#   overrides that set — useful for testing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=$(bash "$SCRIPT_DIR/journal-root.sh")
POINTER="$HOME/.claude/journal-config.json"

# Background flag from the pointer file (absent or non-boolean → treated as off).
BACKGROUND=""
if [ -f "$POINTER" ]; then
  BACKGROUND=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); if (c && typeof c.background === 'boolean') process.stdout.write(String(c.background)); } catch (_) {}" "$POINTER" 2>/dev/null)
fi

if [ "$BACKGROUND" != "true" ]; then
  echo "BACKGROUND_READY=false"
  echo "REASON=background mode not enabled (run /journal setup)"
  exit 0
fi

# Journal root as a permission pattern: home-relative under $HOME, else an
# absolute pattern with a leading // (matches the rules setup installs).
if [[ "$ROOT" == "$HOME"* ]]; then
  ROOT_PATTERN="~${ROOT#$HOME}"
else
  ROOT_PATTERN="/$ROOT"
fi

reqs=(
  "Bash(bash **/journal/*/scripts/*)"
  "Bash(bash **/journal/scripts/*)"
  "Bash(node **/journal/*/scripts/*)"
  "Bash(node **/journal/scripts/*)"
  "Read($ROOT_PATTERN/**)"
  "Write($ROOT_PATTERN/**)"
  "Edit($ROOT_PATTERN/**)"
)

# Settings sources: an explicit override arg, else the user + local settings.
if [ "$#" -ge 1 ]; then
  sources=("$1")
else
  sources=("$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json")
fi

allow_json="[]"
for s in "${sources[@]}"; do
  if [ -f "$s" ]; then
    part=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); process.stdout.write(JSON.stringify((c.permissions && c.permissions.allow) || [])); } catch (_) { process.stdout.write('[]'); }" "$s" 2>/dev/null)
    allow_json=$(node -e "const a = JSON.parse(process.argv[1]), b = JSON.parse(process.argv[2]); process.stdout.write(JSON.stringify(a.concat(b)));" "$allow_json" "$part" 2>/dev/null)
  fi
done

missing=()
for r in "${reqs[@]}"; do
  present=$(node -e "try { const a = JSON.parse(process.argv[1]); process.stdout.write(a.includes(process.argv[2]) ? 'y' : 'n'); } catch (_) { process.stdout.write('n'); }" "$allow_json" "$r" 2>/dev/null)
  [ "$present" = "y" ] || missing+=("$r")
done

if [ ${#missing[@]} -eq 0 ]; then
  echo "BACKGROUND_READY=true"
else
  echo "BACKGROUND_READY=false"
  for r in "${missing[@]}"; do
    echo "MISSING=$r"
  done
fi
exit 0
