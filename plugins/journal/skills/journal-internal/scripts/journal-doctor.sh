#!/usr/bin/env bash
# Diagnostic check for the journal plugin's installation.
# Invoked by /journal doctor. Read-only; prints a checklist of expected state.
set -uo pipefail

ok="✓"
fail="✗"
warn="?"

echo "Journal plugin doctor"
echo "====================="

# 1. Pointer file
POINTER="$HOME/.claude/journal-config.json"
ROOT=""
if [ -f "$POINTER" ]; then
  ROOT=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); if (c && c.journal_root) process.stdout.write(c.journal_root); } catch (_) {}" "$POINTER" 2>/dev/null)
  if [ -n "$ROOT" ]; then
    echo "$ok Pointer file → $ROOT"
  else
    echo "$fail Pointer file at $POINTER exists but journal_root is missing or unparseable"
    echo "    Remedy: run /journal setup"
    ROOT="$HOME/.claude-journal"
  fi
else
  ROOT="${CLAUDE_JOURNAL_ROOT:-$HOME/.claude-journal}"
  echo "$warn Pointer file not set — falling back to $ROOT"
  echo "    Remedy: run /journal setup if you want a persistent journal root"
fi

# 2. Journal root exists
if [ -d "$ROOT" ]; then
  echo "$ok Journal root exists at $ROOT"
else
  echo "$warn Journal root doesn't exist at $ROOT — will be auto-created on next journal"
fi

# 3. Config file
CONFIG="$ROOT/config.json"
if [ -f "$CONFIG" ]; then
  echo "$ok Journal config present ($CONFIG)"
else
  echo "$warn Journal config not yet created — will be auto-created on next journal"
fi

# 4. Auto-journal install
INSTALL="$HOME/.claude/.vive-claude/journal/CLAUDE.md"
if [ -f "$INSTALL" ]; then
  if grep -q "journal:journal-append" "$INSTALL"; then
    echo "$ok Auto-journal installed (references journal-append agent)"
  elif grep -q "journal:journal-worker" "$INSTALL"; then
    echo "$fail Auto-journal installed but references OLD journal-worker agent"
    echo "    Remedy: run /journal setup to install the current template"
  else
    echo "$warn Auto-journal installed but the agent reference is unrecognised"
    echo "    Remedy: run /journal setup to reinstall the current template"
  fi
else
  echo "$fail Auto-journal not installed at $INSTALL"
  echo "    Remedy: run /journal setup"
fi

# 5. Global CLAUDE.md import line
GLOBAL="$HOME/.claude/CLAUDE.md"
if [ -f "$GLOBAL" ] && grep -q ".vive-claude/journal/CLAUDE.md" "$GLOBAL"; then
  echo "$ok Global CLAUDE.md imports auto-journal"
else
  echo "$fail Global CLAUDE.md missing the auto-journal import line"
  echo "    Remedy: run /journal setup"
fi

# 6. Entry count (informational)
if [ -d "$ROOT/entries" ]; then
  count=$(find "$ROOT/entries" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "$ok $count journal entries on disk"
fi
