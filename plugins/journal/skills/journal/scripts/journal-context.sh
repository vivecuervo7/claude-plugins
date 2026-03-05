#!/usr/bin/env bash
# Gathers date, time, and project context for journal entries.
# Output: line 1 = "YYYY-MM-DD HH:MM", line 2 = project, line 3 = git_repo (true/false), line 4 = project_path

date +"%Y-%m-%d %H:%M"

toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "$(basename "$toplevel")"
  echo "true"
else
  echo "$(basename "$PWD")"
  echo "false"
fi
echo "$PWD"
