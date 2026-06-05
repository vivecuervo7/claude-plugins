#!/bin/bash
# Usage: journal-config.sh <journal-root>
# Ensures config.json exists at the journal root, then outputs its content
ROOT="${1:-$HOME/.claude-journal}"
CONFIG="$ROOT/config.json"

if [ ! -f "$CONFIG" ]; then
  mkdir -p "$ROOT"
  cat > "$CONFIG" << 'EOF'
{
  "media_hints_enabled": true
}
EOF
fi
cat "$CONFIG"
