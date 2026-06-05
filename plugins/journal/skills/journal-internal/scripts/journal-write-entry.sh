#!/bin/bash
# Usage: journal-write-entry.sh <path>
# Reads entry content from stdin and writes to path, creating parent directories
mkdir -p "$(dirname "$1")"
cat > "$1"
