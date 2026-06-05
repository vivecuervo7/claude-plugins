#!/bin/bash
# Outputs the resolved journal root path.
# Resolution order: ~/.claude/journal-config.json pointer → $CLAUDE_JOURNAL_ROOT → ~/.claude-journal
set -uo pipefail

POINTER="$HOME/.claude/journal-config.json"
if [ -f "$POINTER" ]; then
  # Parse the pointer JSON with node so escaped paths, alternate spacing,
  # and field ordering all resolve correctly.
  ROOT=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); if (c && c.journal_root) process.stdout.write(c.journal_root); } catch (_) {}" "$POINTER" 2>/dev/null)
  if [ -n "$ROOT" ]; then
    echo "$ROOT"
    exit 0
  fi
fi

if [ -n "${CLAUDE_JOURNAL_ROOT:-}" ]; then
  echo "$CLAUDE_JOURNAL_ROOT"
  exit 0
fi

echo "$HOME/.claude-journal"
