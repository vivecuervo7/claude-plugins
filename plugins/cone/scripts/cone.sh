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
  cone.sh new [--force] [--files|--dirs] <branch> [paths...]
      Create a cone on <branch>. Two modes:

      --dirs (default) — cone-mode sparse-checkout.
        - Branch new + no paths     → root files only
        - Branch new + paths        → cone = those directories
        - Branch exists + no paths  → cone derived from
                                      `git diff <base>...<branch>`
                                      (base = main/master/origin/HEAD)
        - Branch exists + paths     → cone = those directories
        Root files are auto-included. Good for exploratory work where
        the agent will discover what to read as it goes.

      --files — no-cone sparse-checkout with explicit file patterns.
        Patterns are gitignore-style; leading `/` is added if missing
        (anchors at repo root). Root files are NOT auto-included — pass
        them explicitly if needed.
        - Branch new + no patterns       → error (file-mode needs patterns)
        - Branch new + patterns          → cone = those file patterns
        - Branch exists + no patterns    → file list derived from diff
        - Branch exists + patterns       → cone = those file patterns
        Good for targeted work where the files are known upfront
        (renames, surgical edits, peek-required tasks).

      Refuses to spawn inside a Claude plugin repo (catches a common
      wrong-cwd footgun) unless --force is passed.

  cone.sh expand <paths...>
      Add to the current cone. Idempotent. In cone-mode worktrees pass
      directories; in file-mode worktrees pass file patterns (leading
      `/` is added if missing). Run from inside a cone.

  cone.sh list
      List existing worktrees with their cones and mode.

  cone.sh remove <name-or-path> [--force]
      Tear down a cone. Refuses on uncommitted changes unless --force.

  cone.sh help
      Show this help.

NOTES
  Cones are created as siblings of the primary checkout, named
  <repo>-<sanitised-branch>. The cone holds the files/directories the
  agent will edit; verification (builds, tests, linters) runs from your
  primary checkout.
EOF
}

die() { echo "cone: error: $*" >&2; exit 1; }
note() { echo "cone: $*" >&2; }

require_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 \
    || die "not inside a git repository"
}

# Refuse to spawn a worktree if the current git repo looks like a Claude plugin
# development repo (has a top-level .claude-plugin/ directory). This catches a
# common footgun where an agent invokes cone from the orchestrator's cwd (a
# plugin repo) instead of the intended target repo. Override with --force.
guard_against_plugin_repo() {
  local toplevel
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  if [[ -d "$toplevel/.claude-plugin" ]]; then
    die "refusing to spawn a worktree in a Claude plugin repo
       ($toplevel)
   This is usually a wrong-cwd error — you probably meant to invoke
   cone from inside your target repo. cd into the target and try again.
   To override, pass --force."
  fi
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

# File-mode pattern normalization: ensure each pattern has a leading `/` so it
# anchors at the repo root. Without anchoring, `foo.ts` would match any file
# named `foo.ts` anywhere in the tree — almost never what the caller meant.
normalize_file_patterns() {
  local p
  for p in "$@"; do
    [[ -z "$p" ]] && continue
    case "$p" in
      /*) printf '%s\n' "$p" ;;
      *)  printf '/%s\n' "$p" ;;
    esac
  done | sort -u | awk 'NF'
}

print_summary() {
  # print_summary <dir> <branch> <mode> [<entry>...]
  local dir=$1 branch=$2 mode=$3
  shift 3
  echo "worktree: $dir"
  echo "branch:   $branch"
  echo "mode:     $mode"
  if (( $# > 0 )); then
    echo "cone:"
    printf '  %s\n' "$@"
  else
    if [[ "$mode" == "files" ]]; then
      echo "cone:     (empty — file-mode with no patterns)"
    else
      echo "cone:     (root files only)"
    fi
  fi
}

# ---------- subcommands ----------

cmd_new() {
  # Pre-parse: --force, --files, --dirs are positional-agnostic flags.
  local force=0 mode=dirs
  local -a args=()
  while (( $# > 0 )); do
    case "$1" in
      --force) force=1 ;;
      --files) mode=files ;;
      --dirs)  mode=dirs ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  set -- "${args[@]+"${args[@]}"}"

  local branch=${1:-}
  shift || true
  [[ -n "$branch" ]] || die "missing branch name"
  require_in_repo
  (( force == 1 )) || guard_against_plugin_repo

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

  # Compute the include list.
  #   Explicit paths given       → use them (override).
  #   No paths, branch exists    → derive from `git diff <base>...<branch>`.
  #   No paths, branch is new    → empty (cone-mode → root only;
  #                                 file-mode → error, ask for patterns).
  local -a includes=()
  if (( $# > 0 )); then
    if [[ "$mode" == files ]]; then
      while IFS= read -r p; do
        [[ -n "$p" ]] && includes+=("$p")
      done < <(normalize_file_patterns "$@")
    else
      while IFS= read -r d; do
        [[ -n "$d" ]] && includes+=("$d")
      done < <(printf '%s\n' "$@" | normalize_paths_stdin)
    fi
  elif (( branch_exists == 1 )); then
    local base
    base=$(default_base_branch)
    if git rev-parse --verify --quiet "$base" >/dev/null; then
      if [[ "$mode" == files ]]; then
        local -a diff_files=()
        while IFS= read -r f; do
          [[ -n "$f" ]] && diff_files+=("$f")
        done < <(git diff --name-only "$base"..."$start_ref")
        if (( ${#diff_files[@]} > 0 )); then
          while IFS= read -r p; do
            [[ -n "$p" ]] && includes+=("$p")
          done < <(normalize_file_patterns "${diff_files[@]}")
        fi
      else
        while IFS= read -r d; do
          [[ -n "$d" ]] && includes+=("$d")
        done < <(git diff --name-only "$base"..."$start_ref" | normalize_paths_stdin)
      fi
      if (( ${#includes[@]} == 0 )); then
        note "diff ${base}...${branch} produced no entries; cone will be empty"
      fi
    fi
  elif [[ "$mode" == files ]]; then
    die "file-mode on a new branch needs at least one pattern (e.g. /path/to/file.ts)"
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
    if [[ "$mode" == files ]]; then
      git sparse-checkout init --no-cone
    else
      git sparse-checkout init --cone
    fi
    if (( ${#includes[@]} > 0 )); then
      git sparse-checkout set "${includes[@]}"
    fi
    git checkout >/dev/null
  )

  print_summary "$dir" "$branch" "$mode" "${includes[@]}"
}

cmd_expand() {
  (( $# > 0 )) || die "expand: missing paths"
  require_in_repo
  git sparse-checkout list >/dev/null 2>&1 \
    || die "current directory is not a cone (run 'cone new' first)"

  # Detect cone vs no-cone mode from the worktree's git config and route the
  # incoming arguments accordingly: directories for cone-mode, anchored
  # gitignore patterns for file-mode.
  local cone_mode
  cone_mode=$(git config --get core.sparseCheckoutCone 2>/dev/null || echo "false")
  if [[ "$cone_mode" == "true" ]]; then
    git sparse-checkout add "$@"
  else
    local -a patterns=()
    while IFS= read -r p; do
      [[ -n "$p" ]] && patterns+=("$p")
    done < <(normalize_file_patterns "$@")
    git sparse-checkout add "${patterns[@]}"
  fi
  note "expanded: $*"
  echo
  echo "current cone:"
  git sparse-checkout list | sed 's/^/  /'
}

cmd_list() {
  require_in_repo
  local wt br gitdir listing cone_mode mode_label
  while IFS= read -r wt; do
    [[ -z "$wt" ]] && continue
    br=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
    gitdir=$(git -C "$wt" rev-parse --git-dir 2>/dev/null || true)
    echo "$wt  [$br]"
    if [[ -n "$gitdir" && -f "$gitdir/info/sparse-checkout" ]]; then
      cone_mode=$(git -C "$wt" config --get core.sparseCheckoutCone 2>/dev/null || echo "false")
      if [[ "$cone_mode" == "true" ]]; then mode_label="dirs"; else mode_label="files"; fi
      echo "  mode: $mode_label"
      listing=$(git -C "$wt" sparse-checkout list 2>/dev/null || true)
      if [[ -z "$listing" ]]; then
        if [[ "$mode_label" == "files" ]]; then
          echo "  (empty — file-mode with no patterns)"
        else
          echo "  (root files only)"
        fi
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
