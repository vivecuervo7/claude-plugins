#!/usr/bin/env bash
# Resolves the journal root.
# Order: ~/.claude/journal-config.json pointer → $CLAUDE_JOURNAL_ROOT → ~/.claude-journal
set -uo pipefail

POINTER="$HOME/.claude/journal-config.json"
if [ -f "$POINTER" ]; then
  ROOT=$(node -e "try { const c = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); if (c && c.journal_root) process.stdout.write(c.journal_root); } catch (_) {}" "$POINTER" 2>/dev/null)
  if [ -n "$ROOT" ]; then
    echo "$ROOT"
    exit 0
  fi
fi

echo "${CLAUDE_JOURNAL_ROOT:-$HOME/.claude-journal}"
