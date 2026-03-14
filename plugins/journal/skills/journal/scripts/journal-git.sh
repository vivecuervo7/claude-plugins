#!/bin/bash
# Outputs git_repo status and project path
# Line 1: "true" or "false"
# Line 2: absolute project path (git root if in a repo, otherwise cwd)
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "true"
  git rev-parse --show-toplevel 2>/dev/null || echo "$PWD"
else
  echo "false"
  echo "$PWD"
fi
