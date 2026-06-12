---
name: cone
description: "Spin up a cone — a minimal git worktree with sparse-checkout for Claude to make changes in. The agent sees only the directories relevant to the task and can expand the cone on demand. Triggers on /cone slash invocations AND on natural phrases like 'spin up a cone for…', 'narrow this work to…', 'give me a cone for…', 'parallelise this across worktrees'. Five routes: new | expand | list | remove | doctor. Designed for parallelising small edits across a large repo."
user-invocable: true
model: sonnet
argument-hint: "new <branch> [paths...] | expand <paths...> | list | remove <name> [--force] | doctor | <task description>"
allowed-tools: Read, Bash(bash **/cone/*/scripts/*), Bash(git **)
---

# cone

The `/cone` entry point. Parse the first whitespace-separated token of `$ARGUMENTS`, lowercase it, and route to one of the verbs below. If the user describes a task in natural language without a verb, follow the "Proposing a cone from a task description" routine.

## What cones are for

A cone is for editing — Claude reads files, makes changes, commits. The kernel materialises only the directories you ask for, so the agent's working set stays bounded to the change at hand.

**Inside a cone, default to cone-aware search tools.** `rg <pattern>`, `find`, and plain `git grep <pattern>` walk only the materialised cone — their result bodies are bounded to your actual working set. Reach for `git grep <pattern> HEAD` (full-index search) consciously, for the specific case where you need a definitive repo-wide answer (sizing an expand, verifying global completeness before a rename). The point of the cone is that you don't need to look at the rest of the repo most of the time; the search tool should reflect that.

Verification — running tests, linting, building, type-checking — happens in the primary checkout. If the user wants to verify a change runs correctly, point them there:

> Run that in your primary checkout. From this cone: `cd $(git worktree list --porcelain | awk '/^worktree/ { print $2; exit }')`.

## Routes

### `new <branch> [paths...]`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh new <branch> [paths...]
```

Creates a cone on `<branch>`. Behaviour depends on what's given:

| Inputs | Result |
|--------|--------|
| Branch is new, no paths | Branch created off `HEAD`. Cone is root files only. |
| Branch is new, paths given | Branch created off `HEAD`. Cone is those directories. |
| Branch exists (local or `origin/<branch>`), no paths | Branch checked out. Cone derived from `git diff <base>...<branch>` (base = `main`/`master`/`origin/HEAD`). |
| Branch exists, paths given | Branch checked out. Cone is the explicit paths. |

Root files are auto-included in every cone.

### `expand <paths...>`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh expand <paths...>
```

Adds directories to the cone you're currently inside. Idempotent.

Before expanding, consider whether reading is enough — `git show HEAD:<path>` reads from the object store without materialising. Use `expand` when you're about to edit.

### `list`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh list
```

Show all worktrees with their branches and current cones. Read-only.

### `remove <name-or-path> [--force]`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh remove <name> [--force]
```

Tear down a cone. Resolves `<name>` against worktree paths or branch slugs.

### `doctor`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone-doctor.sh
```

Verify git version, repo presence, and base branch detectability. Relay output verbatim.

## Proposing a cone from a task description

When the user says "spin up a cone for the auth refactor" (or similar), follow this routine:

1. **Inspect the tree via git metadata.** The filesystem isn't useful yet — use git's view of the repo:
   ```bash
   git ls-tree -r --name-only HEAD | grep -i <keyword>
   git log --name-only --pretty=format: --all -- '*<keyword>*' | sort -u
   ```
2. **Propose the smallest set of directories** covering the expected change surface. The cone is directory-granular — a file path like `src/auth/login.ts` lives in the directory `src/auth/`, and the cone holds the directory.
3. **Confirm with the user** when ambiguous. In Auto Mode, proceed with the most reasonable proposal and report what you chose.
4. **Run `cone new <branch> <dirs...>`** with the proposed paths.

See `references/discipline.md` for the longer discussion (cone-aware search tools, peek-before-expand, intermediate-parent auto-include, initial cone heuristics, parallelisation patterns).

## Hard rules

- **One verb per invocation.** The skill routes once and exits. Multi-step workflows (spawn N cones, edit in each, tear down) belong to the parent agent calling the skill repeatedly.
- **Surface kernel output as-is.** Its `worktree:` / `branch:` / `cone:` lines are the user's record of what happened.
