#!/usr/bin/env bash
# Bootstrap: emits all context the append/attach playbooks need.
# Output is KEY=VALUE lines.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Date/time (never use the agent's internal clock)
printf 'DATE=%s\n' "$(date +%Y-%m-%d)"
printf 'TIME=%s\n' "$(date +%H:%M)"

# Project context
toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$toplevel" ]; then
  raw_name=$(basename "$toplevel")
  printf 'PROJECT_PATH=%s\n' "$toplevel"
  printf 'GIT_REPO=true\n'
else
  raw_name=$(basename "$PWD")
  printf 'PROJECT_PATH=%s\n' "$PWD"
  printf 'GIT_REPO=false\n'
fi
project=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')
printf 'PROJECT=%s\n' "$project"

# Journal root (delegates to shared helper)
ROOT=$(bash "$SCRIPT_DIR/journal-root.sh")
printf 'JOURNAL_ROOT=%s\n' "$ROOT"
