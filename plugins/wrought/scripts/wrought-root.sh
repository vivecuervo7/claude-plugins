#!/usr/bin/env bash
# Resolves the wrought data root.
# Order: $WROUGHT_ROOT → ~/.claude/.vive-claude/wrought
set -uo pipefail

echo "${WROUGHT_ROOT:-$HOME/.claude/.vive-claude/wrought}"
