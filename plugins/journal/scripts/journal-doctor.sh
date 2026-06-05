#!/usr/bin/env bash
# /journal doctor: read-only checklist of the journal plugin's install state.
set -uo pipefail

ok="✓"; fail="✗"; warn="?"

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

if [ -f "$ROOT/config.json" ]; then
  echo "$ok Journal config present ($ROOT/config.json)"
else
  echo "$warn Journal config not yet created — will be auto-created on next journal"
fi

INSTALL="$HOME/.claude/.vive-claude/journal/CLAUDE.md"
if [ ! -f "$INSTALL" ]; then
  echo "$fail Auto-journal not installed at $INSTALL"
  echo "    Remedy: run /journal setup"
elif grep -q "journal:journal-append" "$INSTALL"; then
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

if [ -d "$ROOT/entries" ]; then
  count=$(find "$ROOT/entries" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "$ok $count journal entries on disk"
fi
