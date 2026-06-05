#!/usr/bin/env bash
set -uo pipefail
# Gathers date, time, and project context for journal entries.
# Output:
#   line 1: "YYYY-MM-DD HH:MM"
#   line 2: sanitised project name (lowercase alphanumeric + hyphens)
#   line 3: git_repo ("true" or "false")
#   line 4: project path (git toplevel when in a repo, otherwise cwd)

date +"%Y-%m-%d %H:%M"

toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$toplevel" ]; then
  raw_name=$(basename "$toplevel")
  project_path="$toplevel"
  git_repo="true"
else
  raw_name=$(basename "$PWD")
  project_path="$PWD"
  git_repo="false"
fi

# Sanitise: lowercase, replace non-alphanumeric runs with single hyphen, trim hyphens
echo "$raw_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//'
echo "$git_repo"
echo "$project_path"
