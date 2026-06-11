#!/usr/bin/env bash
# cone.sh — minimal git worktrees with sparse-checkout cones, for editing.
# Companion to the /cone skill. Cones hold only the directories the agent
# will edit; verification (builds, tests, linters) runs from the primary
# checkout.
set -euo pipefail

usage() {
  cat <<'EOF'
cone.sh — minimal git worktrees with sparse-checkout cones for editing.

USAGE
  cone.sh new <branch> [paths...]
      Create a cone on <branch>.
        - Branch new + no paths     → root files only
        - Branch new + paths        → cone = those directories
        - Branch exists + no paths  → cone derived from
                                      `git diff <base>...<branch>`
                                      (base = main/master/origin/HEAD)
        - Branch exists + paths     → cone = those directories

  cone.sh expand <paths...>
      Add directories to the current cone. Idempotent.
      Run from inside a cone.

  cone.sh list
      List existing worktrees with their cones.

  cone.sh remove <name-or-path> [--force]
      Tear down a cone. Refuses on uncommitted changes unless --force.

  cone.sh help
      Show this help.

NOTES
  Cones are created as siblings of the primary checkout, named
  <repo>-<sanitised-branch>. Cone mode is used; root files are
  auto-included. The cone holds the directories the agent will edit;
  verification (builds, tests, linters) runs from your primary checkout.
EOF
}

die() { echo "cone: error: $*" >&2; exit 1; }
note() { echo "cone: $*" >&2; }

require_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 \
    || die "not inside a git repository"
}

primary_root() {
  git worktree list --porcelain | awk '/^worktree / { print $2; exit }'
}

sanitize_branch() {
  echo "$1" | tr '/' '-' | tr -cd 'A-Za-z0-9._-'
}

worktree_dir_for() {
  local branch=$1
  local primary repo parent
  primary=$(primary_root)
  repo=$(basename "$primary")
  parent=$(dirname "$primary")
  echo "$parent/${repo}-$(sanitize_branch "$branch")"
}

default_base_branch() {
  local b
  if b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
    echo "${b#origin/}"; return
  fi
  if git show-ref --verify --quiet refs/heads/main; then echo main; return; fi
  if git show-ref --verify --quiet refs/heads/master; then echo master; return; fi
  die "could not determine base branch; pass it explicitly as the second arg"
}

# Read paths on stdin, emit unique cone-compatible directories.
# Cone-mode `git sparse-checkout set` requires DIRECTORIES — passing a file
# path generates a bogus rule like `/path/to/file.ts/` that silently fails to
# materialise the file (the only reason it sometimes "works" is the parent dir
# gets auto-included as a navigation aid in cone mode).
#
# Strategy: stat each path against the repo root. Dir → as-is. File → dirname.
# Doesn't exist on disk → dot-in-basename heuristic (covers diff-derived paths
# that may not exist in the primary checkout). Root-level paths are dropped
# because cone mode auto-includes root files.
normalize_paths_stdin() {
  local root p base
  root=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
  while IFS= read -r p; do
    p=${p%/}
    [[ -z "$p" || "$p" == "." ]] && continue
    [[ "$p" != */* ]] && continue
    if [[ -d "$root/$p" ]]; then
      printf '%s\n' "$p"
    elif [[ -f "$root/$p" ]]; then
      printf '%s\n' "${p%/*}"
    else
      base=${p##*/}
      if [[ "$base" == *.* ]]; then
        printf '%s\n' "${p%/*}"
      else
        printf '%s\n' "$p"
      fi
    fi
  done | sort -u | awk 'NF'
}

print_summary() {
  # print_summary <dir> <branch> [<cone>...]
  local dir=$1 branch=$2
  shift 2
  echo "worktree: $dir"
  echo "branch:   $branch"
  if (( $# > 0 )); then
    echo "cone:"
    printf '  %s\n' "$@"
  else
    echo "cone:     (root files only)"
  fi
}

# ---------- subcommands ----------

cmd_new() {
  local branch=${1:-}
  shift || true
  [[ -n "$branch" ]] || die "missing branch name"
  require_in_repo

  local dir
  dir=$(worktree_dir_for "$branch")
  [[ ! -e "$dir" ]] || die "$dir already exists"

  # Identify the starting point and whether the branch already exists.
  local branch_exists=0 start_ref=""
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    branch_exists=1
    start_ref="$branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    branch_exists=1
    start_ref="origin/$branch"
  fi

  # Compute the cone.
  #   Explicit paths given     → use them (override).
  #   No paths, branch exists  → derive from `git diff <base>...<branch>`.
  #   No paths, branch is new  → empty cone (root files only).
  local -a cone=()
  if (( $# > 0 )); then
    while IFS= read -r d; do
      [[ -n "$d" ]] && cone+=("$d")
    done < <(printf '%s\n' "$@" | normalize_paths_stdin)
  elif (( branch_exists == 1 )); then
    local base
    base=$(default_base_branch)
    if git rev-parse --verify --quiet "$base" >/dev/null; then
      while IFS= read -r d; do
        [[ -n "$d" ]] && cone+=("$d")
      done < <(git diff --name-only "$base"..."$start_ref" | normalize_paths_stdin)
      if (( ${#cone[@]} == 0 )); then
        note "diff ${base}...${branch} touches only root files; cone will be root-only"
      fi
    fi
  fi

  # Create the worktree.
  if (( branch_exists == 1 )); then
    if [[ "$start_ref" == "origin/$branch" ]]; then
      git worktree add --no-checkout "$dir" -b "$branch" "$start_ref" >/dev/null
    else
      git worktree add --no-checkout "$dir" "$branch" >/dev/null
    fi
  else
    git worktree add --no-checkout "$dir" -b "$branch" >/dev/null
  fi

  (
    cd "$dir"
    git sparse-checkout init --cone
    if (( ${#cone[@]} > 0 )); then
      git sparse-checkout set "${cone[@]}"
    fi
    git checkout >/dev/null
  )

  print_summary "$dir" "$branch" "${cone[@]}"
}

cmd_expand() {
  (( $# > 0 )) || die "expand: missing paths"
  require_in_repo
  git sparse-checkout list >/dev/null 2>&1 \
    || die "current directory is not a cone (run 'cone new' first)"

  git sparse-checkout add "$@"
  note "expanded: $*"
  echo
  echo "current cone:"
  git sparse-checkout list | sed 's/^/  /'
}

cmd_list() {
  require_in_repo
  local wt br gitdir listing
  while IFS= read -r wt; do
    [[ -z "$wt" ]] && continue
    br=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
    gitdir=$(git -C "$wt" rev-parse --git-dir 2>/dev/null || true)
    echo "$wt  [$br]"
    # A worktree has a sparse-checkout if its gitdir/info/sparse-checkout exists.
    # `git sparse-checkout list` then gives us the clean user-facing dir list.
    if [[ -n "$gitdir" && -f "$gitdir/info/sparse-checkout" ]]; then
      listing=$(git -C "$wt" sparse-checkout list 2>/dev/null || true)
      if [[ -z "$listing" ]]; then
        echo "  (root files only)"
      else
        echo "$listing" | sed 's/^/  /'
      fi
    else
      echo "  (no sparse cone — full checkout)"
    fi
  done < <(git worktree list --porcelain | awk '/^worktree / { print $2 }')
}

cmd_remove() {
  local target=${1:-} flag=${2:-}
  [[ -n "$target" ]] || die "remove: missing name or path"
  require_in_repo

  # Resolve target: explicit path, then sanitised-branch match against worktree dirs.
  local dir=""
  if [[ -d "$target" ]]; then
    dir=$(cd "$target" && pwd)
  else
    local slug
    slug=$(sanitize_branch "$target")
    while IFS= read -r wt; do
      if [[ "$(basename "$wt")" == *"$slug"* ]]; then
        dir=$wt
        break
      fi
    done < <(git worktree list --porcelain | awk '/^worktree / { print $2 }')
  fi

  [[ -n "$dir" ]] || die "no worktree matching '$target'"
  [[ "$dir" != "$(primary_root)" ]] || die "refusing to remove the primary worktree"

  if [[ "$flag" == "--force" ]]; then
    git worktree remove --force "$dir"
  else
    git worktree remove "$dir"
  fi
  note "removed: $dir"
}

main() {
  local cmd=${1:-help}
  shift || true
  case "$cmd" in
    new)    cmd_new "$@" ;;
    expand) cmd_expand "$@" ;;
    list)   cmd_list "$@" ;;
    remove) cmd_remove "$@" ;;
    help|-h|--help) usage ;;
    *) usage >&2; die "unknown command: $cmd" ;;
  esac
}

main "$@"
