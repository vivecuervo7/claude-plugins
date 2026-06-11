#!/usr/bin/env bash
# cone-doctor.sh — verify environment supports sparse-checkout cones.
# Read-only. Prints a checklist; non-zero exit if any check fails.
set -uo pipefail

PASS="✓"
FAIL="✗"

failures=0
total=0

check() {
  local name=$1 remedy=$2
  shift 2
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  $PASS $name"
  else
    echo "  $FAIL $name"
    [[ -n "$remedy" ]] && echo "      → $remedy"
    failures=$((failures + 1))
  fi
}

# Predicates.
git_version_ok() {
  command -v git >/dev/null || return 1
  local v major minor
  v=$(git --version | awk '{print $3}')
  major=$(echo "$v" | cut -d. -f1)
  minor=$(echo "$v" | cut -d. -f2)
  if (( major > 2 )); then return 0; fi
  if (( major == 2 )) && (( minor >= 27 )); then return 0; fi
  return 1
}

in_repo() { git rev-parse --git-dir >/dev/null 2>&1; }

base_branch_resolves() {
  git symbolic-ref --short refs/remotes/origin/HEAD >/dev/null 2>&1 \
    || git show-ref --verify --quiet refs/heads/main \
    || git show-ref --verify --quiet refs/heads/master
}

not_shallow() {
  local gitdir
  gitdir=$(git rev-parse --git-dir 2>/dev/null) || return 0
  [[ ! -f "$gitdir/shallow" ]]
}

echo "cone: doctor"
echo

check "git installed and >= 2.27 (cone mode)" \
  "upgrade git: https://git-scm.com/downloads" \
  git_version_ok

check "inside a git repository" \
  "cd into a git repository and re-run" \
  in_repo

check "base branch detectable (main/master/origin/HEAD)" \
  "set origin/HEAD with 'git remote set-head origin --auto', or pass explicit paths to 'cone new' to skip auto-derivation" \
  base_branch_resolves

check "not a shallow clone" \
  "unshallow with 'git fetch --unshallow' for cleanest behaviour" \
  not_shallow

echo
if (( failures == 0 )); then
  echo "cone: ready ($total/$total checks passed)"
  exit 0
else
  echo "cone: $((total - failures))/$total checks passed"
  exit 1
fi
