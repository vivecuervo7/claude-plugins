#!/bin/bash
# Check if a recap nudge is due. Called from a PreToolUse hook.
# Reads stdin (required by hooks) and discards it.
# Outputs nothing on the fast path (already checked today or disabled).
# Outputs a nudge message to stderr and exits 2 when a recap is due.
#
# Nudge fires when:
#   1. Today matches recap_nudge_day (default: monday)
#   2. Current hour >= recap_nudge_hour (default: 8)
#   3. No recap has been compiled since the start of the current window

cat > /dev/null

# Resolve journal root
POINTER="$HOME/.claude/journal-config.json"
if [ -f "$POINTER" ]; then
  JOURNAL_ROOT=$(python3 -c "import json; print(json.load(open('$POINTER'))['journal_root'])" 2>/dev/null)
fi
JOURNAL_ROOT="${JOURNAL_ROOT:-$HOME/.claude-journal}"

# Fast path: if we already checked today, exit silently
STATE_FILE="$JOURNAL_ROOT/.recap-nudge-date"
TODAY=$(date +%Y-%m-%d)

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

# Mark today as checked (regardless of whether we nudge)
echo "$TODAY" > "$STATE_FILE" 2>/dev/null

# Check if nudges are enabled in config
CONFIG="$JOURNAL_ROOT/config.json"
if [ ! -f "$CONFIG" ]; then
  exit 0
fi

ENABLED=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('recap_nudge_enabled', False))" 2>/dev/null)
if [ "$ENABLED" != "True" ]; then
  exit 0
fi

# Read nudge schedule from config
NUDGE_DAY=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('recap_nudge_day', 'monday'))" 2>/dev/null)
NUDGE_HOUR=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('recap_nudge_hour', 8))" 2>/dev/null)
RECAP_DAYS=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('default_recap_days', 7))" 2>/dev/null)
NUDGE_DAY="${NUDGE_DAY:-monday}"
NUDGE_HOUR="${NUDGE_HOUR:-8}"
RECAP_DAYS="${RECAP_DAYS:-7}"

# Check if today is the nudge day
# date +%u: 1=Monday ... 7=Sunday
CURRENT_DAY_NUM=$(date +%u)
case "$NUDGE_DAY" in
  monday)    TARGET_DAY=1 ;;
  tuesday)   TARGET_DAY=2 ;;
  wednesday) TARGET_DAY=3 ;;
  thursday)  TARGET_DAY=4 ;;
  friday)    TARGET_DAY=5 ;;
  saturday)  TARGET_DAY=6 ;;
  sunday)    TARGET_DAY=7 ;;
  *)         TARGET_DAY=1 ;;
esac

if [ "$CURRENT_DAY_NUM" != "$TARGET_DAY" ]; then
  exit 0
fi

# Check if current hour is at or past nudge hour
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" -lt "$NUDGE_HOUR" ]; then
  exit 0
fi

# Check if a recap has already been compiled this window
LAST_RECAP_FILE="$JOURNAL_ROOT/.last-recap-date"
if [ -f "$LAST_RECAP_FILE" ]; then
  LAST_RECAP=$(cat "$LAST_RECAP_FILE" 2>/dev/null)

  # Calculate days since last recap
  LAST_TS=$(date -j -f "%Y-%m-%d" "$LAST_RECAP" "+%s" 2>/dev/null || date -d "$LAST_RECAP" "+%s" 2>/dev/null)
  TODAY_TS=$(date -j -f "%Y-%m-%d" "$TODAY" "+%s" 2>/dev/null || date -d "$TODAY" "+%s" 2>/dev/null)

  if [ -n "$LAST_TS" ] && [ -n "$TODAY_TS" ]; then
    DIFF_DAYS=$(( (TODAY_TS - LAST_TS) / 86400 ))
    if [ "$DIFF_DAYS" -lt "$RECAP_DAYS" ]; then
      exit 0
    fi
  fi
fi

# Check if there are any entries to recap
HAS_ENTRIES=false
for idx in "$JOURNAL_ROOT"/entries/*/*/index.json; do
  [ -f "$idx" ] && HAS_ENTRIES=true && break
done

if [ "$HAS_ENTRIES" = false ]; then
  exit 0
fi

# Nudge the agent
echo "A journal recap is available for the previous week. Mention to the user: \"A weekly journal recap is available — run \`/journal recap\` when you're ready.\"" >&2
exit 2
