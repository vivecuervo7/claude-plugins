#!/usr/bin/env bash
# /journal doctor: read-only checklist of the journal plugin's install state.
set -uo pipefail

ok="✓"; fail="✗"; warn="?"; info="○"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=$(bash "$SCRIPT_DIR/journal-root.sh")

echo "Journal plugin doctor"
echo "====================="

POINTER="$HOME/.claude/journal-config.json"
if [ -f "$POINTER" ]; then
  echo "$ok Pointer file → $ROOT"
else
  echo "$warn Pointer file not set — falling back to $ROOT"
  echo "    Remedy: run /journal setup if you want a persistent journal root"
fi

if [ -d "$ROOT" ]; then
  echo "$ok Journal root exists at $ROOT"
else
  echo "$warn Journal root doesn't exist at $ROOT — will be auto-created on next journal"
fi

# These two constants (install path + agent sentinel) must stay in sync with the
# Constants block in skills/journal/references/setup.md and the templates/auto-journal*.md files.
INSTALL="$HOME/.claude/.vive-claude/journal/CLAUDE.md"
SENTINEL="journal:journal-append"

# Honour an explicit opt-out recorded by setup. If auto_journal is false, the
# user declined the install on purpose — report that instead of failing.
AUTO_JOURNAL=""
if [ -f "$POINTER" ]; then
  AUTO_JOURNAL=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); if (c && typeof c.auto_journal === 'boolean') process.stdout.write(String(c.auto_journal)); } catch (_) {}" "$POINTER" 2>/dev/null)
fi

if [ "$AUTO_JOURNAL" = "false" ]; then
  echo "$info Auto-journaling declined by choice (re-run /journal setup to enable)"
else
  if [ ! -f "$INSTALL" ]; then
    echo "$fail Auto-journal not installed at $INSTALL"
    echo "    Remedy: run /journal setup"
  elif grep -q "$SENTINEL" "$INSTALL"; then
    echo "$ok Auto-journal installed"
  else
    echo "$warn Auto-journal installed but agent reference is unrecognised"
    echo "    Remedy: run /journal setup to reinstall the current template"
  fi

  GLOBAL="$HOME/.claude/CLAUDE.md"
  if [ -f "$GLOBAL" ] && grep -q ".vive-claude/journal/CLAUDE.md" "$GLOBAL"; then
    echo "$ok Global CLAUDE.md imports auto-journal"
  else
    echo "$fail Global CLAUDE.md missing the auto-journal import line"
    echo "    Remedy: run /journal setup"
  fi
fi

# --- Background readiness ---
# Delegates to journal-ready.sh — the single source of truth — so the rule
# computation lives in one place. Read-only; the script always exits 0.
READY_OUT=$(bash "$SCRIPT_DIR/journal-ready.sh" 2>/dev/null)
BG_READY=$(printf '%s\n' "$READY_OUT" | grep '^BACKGROUND_READY=' | head -1 | cut -d '=' -f2)
BG_REASON=$(printf '%s\n' "$READY_OUT" | grep '^REASON=' | head -1 | cut -d '=' -f2-)

if [ "$BG_READY" = "true" ]; then
  echo "$ok Background-ready"
  # Drift: pointer says background, but the installed template isn't the variant.
  if [ -f "$INSTALL" ] && ! grep -q "journal-ready.sh" "$INSTALL"; then
    echo "$warn Installed auto-journal isn't the background variant — background won't trigger"
    echo "    Remedy: run /journal setup to reinstall"
  fi
elif [ -n "$BG_REASON" ]; then
  echo "$info Background mode off — $BG_REASON"
else
  echo "$fail Background mode enabled but not ready — run /journal setup:"
  printf '%s\n' "$READY_OUT" | grep '^MISSING=' | while IFS= read -r line; do
    echo "$fail   missing rule: ${line#MISSING=}"
  done
  if [ -f "$INSTALL" ] && ! grep -q "journal-ready.sh" "$INSTALL"; then
    echo "$fail   installed auto-journal isn't the background variant"
  fi
fi

if [ -d "$ROOT/entries" ]; then
  count=$(find "$ROOT/entries" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "$ok $count journal entries on disk"
fi
