---
name: cone
description: "Spin up a cone — a minimal git worktree with sparse-checkout for Claude to make changes in. The agent sees only the directories relevant to the task and can expand the cone on demand. Triggers on /cone slash invocations AND on natural phrases like 'spin up a cone for…', 'narrow this work to…', 'give me a cone for…', 'parallelise this across worktrees'. Five routes: new | expand | list | remove | doctor. Designed for parallelising small edits across a large repo."
user-invocable: true
model: sonnet
argument-hint: "new [--files|--dirs] <branch> [paths...] | expand <paths...> | list | remove <name> [--force] | doctor | <task description>"
allowed-tools: Read, Bash(bash **/cone/*/scripts/*), Bash(git **)
---

# cone

The `/cone` entry point. Parse the first whitespace-separated token of `$ARGUMENTS`, lowercase it, and route to one of the verbs below. If the user describes a task in natural language without a verb, follow the "Proposing a cone from a task description" routine.

## What cones are for

A cone is for editing — Claude reads files, makes changes, commits. The kernel materialises only what you ask for, so the agent's working set stays bounded to the change at hand.

The kernel offers two materialisation modes:

- **dir-mode (`--dirs`, default)** — sparse-checkout cone-mode. Includes whole directories plus the root files of every intermediate parent. Right for exploratory work: the agent will be discovering files and wants room to `rg` / `Read` / `Glob` across a region.
- **file-mode (`--files`)** — sparse-checkout no-cone with anchored gitignore patterns. Includes exactly the files you name (root files are NOT auto-included). Right for targeted work: renames, surgical single-file edits, peek-required tasks where every needed file is known upfront.

**Inside a cone, default to cone-aware search tools.** `rg <pattern>`, `find`, and plain `git grep <pattern>` walk only the materialised cone — their result bodies are bounded to your actual working set. Reach for `git grep <pattern> HEAD` (full-index search) consciously, for the specific case where you need a definitive repo-wide answer (sizing an expand, verifying global completeness before a rename). The point of the cone is that you don't need to look at the rest of the repo most of the time; the search tool should reflect that.

Verification — running tests, linting, building, type-checking — happens in the primary checkout. If the user wants to verify a change runs correctly, point them there:

> Run that in your primary checkout. From this cone: `cd $(git worktree list --porcelain | awk '/^worktree/ { print $2; exit }')`.

## Routes

### `new [--files|--dirs] <branch> [paths...]`

```bash
# Dir-mode (default) — pass directories
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh new <branch> [paths...]

# File-mode — pass file patterns (leading `/` is added if missing)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh new --files <branch> <patterns...>
```

Creates a cone on `<branch>`. Behaviour depends on mode and what's given:

**Dir-mode (default).** Root files are auto-included in every cone.

| Inputs | Result |
|--------|--------|
| Branch is new, no paths | Branch created off `HEAD`. Cone is root files only. |
| Branch is new, paths given | Branch created off `HEAD`. Cone is those directories. |
| Branch exists (local or `origin/<branch>`), no paths | Branch checked out. Cone derived from `git diff <base>...<branch>`. |
| Branch exists, paths given | Branch checked out. Cone is the explicit directories. |

**File-mode (`--files`).** Patterns are gitignore-style, anchored at the repo root. Root files are NOT auto-included.

| Inputs | Result |
|--------|--------|
| Branch is new, no patterns | Error — file-mode needs at least one pattern. |
| Branch is new, patterns given | Branch created off `HEAD`. Cone is those file patterns. |
| Branch exists, no patterns | Branch checked out. File list derived from `git diff <base>...<branch>`. |
| Branch exists, patterns given | Branch checked out. Cone is the explicit patterns. |

### `expand <paths...>`

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh expand <paths...>
```

Adds to the cone you're currently inside. Idempotent. The kernel routes the arguments based on the worktree's mode — directories for dir-mode cones, file patterns for file-mode cones.

Before expanding, consider whether reading is enough — `git show HEAD:<path>` reads from the object store without materialising. Reach for `expand` when:

- You're about to edit a file/directory not in the cone
- A new file you just created in a file-mode cone needs to be tracked (run `expand /path/to/new-file.ts` before `git add`)
- You want `rg` / `find` / cone-aware `git grep` to walk across a region you don't yet have on disk

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

1. **Choose the mode** based on what the task looks like:

   | Task shape | Mode | Why |
   |---|---|---|
   | Rename across N call sites; all targets known via `git grep`/repo knowledge | **file-mode** | The file list is enumerable. Materialise exactly those files. |
   | Single-file edit (typo, error-message tweak, bugfix at a known line) | **file-mode** | The change is one file. Add peek targets to the file list as needed. |
   | Peek-required JSDoc/refactor with one or two known cross-references | **file-mode** | Pass the edit file + the peek file as a 2-entry list. |
   | Substantial feature work; agent will be discovering files as it goes | **dir-mode** | The agent needs room to read precedents, sibling files, configs. |
   | Refactor of unknown scope; need to explore before deciding | **dir-mode** | Start dir-mode, expand on demand. |
   | Resuming an existing branch | matches the branch's history | Pass no paths; the kernel derives from the diff. Dir-mode for the dir form, `--files` for the file form. |

   The general principle: **file-mode when the file list is knowable upfront; dir-mode when discovery is part of the task.** When in doubt for ambiguous cases, dir-mode is safer (one expand fixes a too-narrow cone; file-mode mid-task expansion is more granular).

2. **Inspect the tree via git metadata** to size the proposal. The filesystem isn't useful yet — use git's view of the repo:
   ```bash
   git ls-tree -r --name-only HEAD | grep -i <keyword>
   git log --name-only --pretty=format: --all -- '*<keyword>*' | sort -u
   git grep -l <symbol> HEAD          # full-index search — best for rename surfaces
   ```

3. **Propose the smallest entry list** that covers the expected change surface.
   - For file-mode: the explicit set of files the agent will edit + any required peek targets.
   - For dir-mode: directories. A file like `src/auth/login.ts` lives in `src/auth/`, and the cone holds the directory.

4. **Confirm with the user when ambiguous.** In Auto Mode, proceed with the most reasonable proposal and report what you chose.

5. **Run the kernel** with the chosen mode:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh new --files <branch> <patterns...>
   # or
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/cone.sh new <branch> <dirs...>
   ```

6. **Report the mode decision in your response.** A one-line note above the kernel output is enough — e.g. *"Going with file-mode: the rename targets are enumerable upfront."* The user can redirect if the call was wrong, and downstream readers can see why the cone is shaped the way it is.

See `references/discipline.md` for the longer discussion (mode selection, cone-aware search tools, peek-before-expand, intermediate-parent auto-include, file-mode new-file handling, parallelisation patterns).

## Hard rules

- **One verb per invocation.** The skill routes once and exits. Multi-step workflows (spawn N cones, edit in each, tear down) belong to the parent agent calling the skill repeatedly.
- **Surface kernel output as-is.** Its `worktree:` / `branch:` / `mode:` / `cone:` lines are the user's record of what happened.
- **Always state the mode decision** when proposing a cone from a task description. One sentence above the kernel output is enough; it makes the choice auditable.
