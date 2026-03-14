#!/bin/bash
# Outputs the resolved journal root path
# Checks ~/.claude/journal-config.json, then $CLAUDE_JOURNAL_ROOT, then default
POINTER="$HOME/.claude/journal-config.json"
if [ -f "$POINTER" ]; then
  ROOT=$(grep '"journal_root"' "$POINTER" | sed 's/.*"journal_root"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  if [ -n "$ROOT" ]; then
    echo "$ROOT"
    exit 0
  fi
fi
if [ -n "$CLAUDE_JOURNAL_ROOT" ]; then
  echo "$CLAUDE_JOURNAL_ROOT"
  exit 0
fi
echo "$HOME/.claude-journal"
