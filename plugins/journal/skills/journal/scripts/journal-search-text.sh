#!/bin/bash
# Search journal entry body text using grep.
# Usage: journal-search-text.sh <journal-root> <search-terms> [file1 file2 ...]
#
# If specific files are provided, searches only those files.
# Otherwise, searches all entry .md files under <journal-root>/entries/.
#
# Output: matching file paths with context lines (grep -l style + excerpts).

set -euo pipefail

JOURNAL_ROOT="$1"
SEARCH_TERMS="$2"
shift 2

if [ -z "$JOURNAL_ROOT" ] || [ -z "$SEARCH_TERMS" ]; then
  echo "Usage: journal-search-text.sh <journal-root> <search-terms> [file1 file2 ...]" >&2
  exit 1
fi

# Determine search targets
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$JOURNAL_ROOT/entries" -name "*.md" -type f -print0 2>/dev/null | sort -z)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "[]"
  exit 0
fi

# Search with context, case-insensitive
# Output JSON array of matches for easy consumption
echo "["
first=true
for f in "${FILES[@]}"; do
  if grep -qi "$SEARCH_TERMS" "$f" 2>/dev/null; then
    # Get matching lines with 1 line of context
    context=$(grep -ni -m 3 "$SEARCH_TERMS" "$f" 2>/dev/null | head -5)
    # Extract relative path from journal root
    relpath="${f#"$JOURNAL_ROOT/"}"

    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi

    # Escape JSON strings
    escaped_path=$(printf '%s' "$relpath" | sed 's/\\/\\\\/g; s/"/\\"/g')
    escaped_context=$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '|' | sed 's/|$//')

    printf '  {"path": "%s", "matches": "%s"}' "$escaped_path" "$escaped_context"
  fi
done
echo ""
echo "]"
