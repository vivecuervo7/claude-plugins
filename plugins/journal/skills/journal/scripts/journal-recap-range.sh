#!/bin/bash
# Calculate the recap date range for "previous completed week" (Mon–Sun).
# Usage: journal-recap-range.sh [reference-date]
#   reference-date: optional YYYY-MM-DD to calculate from (default: today)
#
# Output: two lines
#   YYYY-MM-DD   (from: Monday of the previous completed week)
#   YYYY-MM-DD   (to: Sunday of the previous completed week)
#
# Example: if reference is Wednesday 2026-05-07
#   from = 2026-04-28 (Monday)
#   to   = 2026-05-04 (Sunday)
#
# If reference is Monday, "previous completed week" is the week before last
# (the week ending yesterday is complete, but we go back one more to avoid
# recapping a partial day on Monday morning).

set -euo pipefail

REF="${1:-$(date +%Y-%m-%d)}"

# day_of_week: 1=Monday ... 7=Sunday
if date -j -f "%Y-%m-%d" "$REF" "+%u" > /dev/null 2>&1; then
  # macOS
  DOW=$(date -j -f "%Y-%m-%d" "$REF" "+%u")
  offset_to_prev_monday=$(( DOW + 6 ))  # days back to Monday of previous week
  FROM=$(date -j -v-${offset_to_prev_monday}d -f "%Y-%m-%d" "$REF" "+%Y-%m-%d")
  TO=$(date -j -v-$(( DOW ))d -f "%Y-%m-%d" "$REF" "+%Y-%m-%d")
else
  # GNU/Linux
  DOW=$(date -d "$REF" "+%u")
  offset_to_prev_monday=$(( DOW + 6 ))
  FROM=$(date -d "$REF - ${offset_to_prev_monday} days" "+%Y-%m-%d")
  TO=$(date -d "$REF - ${DOW} days" "+%Y-%m-%d")
fi

echo "$FROM"
echo "$TO"
