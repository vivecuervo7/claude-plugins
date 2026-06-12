# cone discipline

Several patterns govern how the agent should use a cone.

## 0. Two modes, one tool

The kernel offers two materialisation modes. Picking the right one for the task shape is the first lever.

| Mode | Granularity | Best for |
|---|---|---|
| **dir-mode** (`--dirs`, default) | Whole directories + auto-included root files of every intermediate parent | Exploratory work — substantial features, refactors of unknown scope, anything where the agent needs to discover files |
| **file-mode** (`--files`) | Exactly the files matching the patterns | Targeted work — renames with known call sites, single-file edits, peek-required JSDoc with known cross-references |

**File-mode wins when the file list is knowable upfront.** A typo fix needs one file. A rename's call sites surface via `git grep -l <symbol> HEAD` before the cone is spawned. A "JSDoc this function and link to that type" task names both files in the prompt. Materialising exactly those files keeps the cone small and the agent's exploration tightly scoped.

**Dir-mode wins when discovery is part of the task.** A substantial feature requires reading precedents, sibling configs, the surrounding subsystem. Pre-enumerating every file would force the agent into a `git show HEAD:` peek dance for every discovery — five peeks cost more tokens than one wider initial cone. Materialise the region; let the agent navigate inside it.

**Cost model.** File-mode pays an upfront cost (enumeration) and saves on the working set. Dir-mode pays a wider working set and saves on per-discovery overhead. The crossover is shape, not size: how knowable is the file list at the moment you spawn the cone?

## 1. Discovery uses cone-aware tools

Different search tools see different things from inside a cone — choosing the right one is the biggest lever the cone gives you. Default to cone-aware search; reach for full-index search consciously.

| Tool | Scope | When to use |
|---|---|---|
| `rg <pattern>` / `find` / `glob` | The materialised cone only | Default. You're searching the work you've decided to do. |
| `git grep <pattern>` (no ref) | The materialised cone only | Default for git-native search. |
| `git ls-tree -r --name-only HEAD` | The full repo from the object store | Sizing an initial cone or expand — you need the repo's shape, not its content. |
| `git grep <pattern> HEAD` | The full index from the object store | You need a definitive repo-wide answer (e.g. "every caller of this symbol" before a rename). Pay the breadth cost on purpose. |

The mechanism: cone-aware tools walk what's on disk; index/object-store tools walk what git knows about. Both are valid; the second is more expensive in tokens because the result body is repo-wide. Pick the smallest tool that answers your question.

## 2. Peek before you expand

For "I need to look at a file outside my cone," `git show` is the default — not `expand`. Reading from the object store is free; expanding the cone is a permanent broadening of the working set within the session.

```bash
# Read a single file outside the cone
git show HEAD:src/utils/helpers.ts

# Read at a specific ref
git show main:config/database.yml

# List what's in a directory you haven't materialised
git ls-tree --name-only HEAD src/utils/
```

Reach for `expand` when:

- You're about to make an edit
- You created a new file in a file-mode cone (it must be added to the cone before `git add` will track it — see §3.5)
- You need `rg` / `find` / cone-aware `git grep` to walk across a directory's contents
- The file needs to exist on disk for a tool you're running

## 3. Propose directories (dir-mode)

Dir-mode is directory-granular. Including `src/auth/login.ts` means including the rest of `src/auth/` along with it — the directory is the unit. When sizing an initial dir-mode cone, think in directories from the start.

For a task that touches:

- `src/auth/login.ts`
- `src/auth/refresh.ts`
- `src/users/profile.ts`

The cone is `src/auth/ src/users/`.

**Dir-mode also auto-includes root-level files of every parent directory along the path.** When you add `apps/web/components/` to your cone, materialisation includes:

- `apps/web/components/` and everything below it (the cone target)
- Root-level files of `apps/web/` (configs, manifests, indices at that level)
- Root-level files of `apps/` (configs at that level)
- Root-level files of the repo (always materialised by cone mode)

So when a top-level file at an intermediate parent is what you need (a workspace-shared utility, a config, a test helper), coning the nested subdirectory you actually edit is enough — the intermediate parent's loose files come along for free, without materialising the parent's other subdirectories.

If a task seems to touch root-level files only (e.g. `index.html`, `about.html`, `package.json`), the cone is **empty** — root files are auto-included by dir-mode. `cone new <branch>` with no paths gives you exactly that minimum.

## 3.5. Propose file patterns (file-mode)

File-mode is file-granular. Patterns are gitignore-style with leading `/` to anchor at the repo root (the kernel adds the slash if missing).

For a rename whose call sites are:

- `packages/lib/src/utils.ts` (definition)
- `packages/lib/src/runner.ts` (caller)
- `apps/web/src/feature.ts` (caller)
- `apps/web/__tests__/feature.spec.ts` (test)

The file-mode cone is `/packages/lib/src/utils.ts /packages/lib/src/runner.ts /apps/web/src/feature.ts /apps/web/__tests__/feature.spec.ts`.

**File-mode does NOT auto-include root files.** If the task needs `CLAUDE.md`, `package.json`, or repo-root configs, either:

- `git show HEAD:CLAUDE.md` (peek) — free, no working-set growth
- include the root file in the initial pattern list

**New files in file-mode need to be added to the cone before staging.** Sparse-checkout treats files outside the patterns as "ignored, do not track" — so `git add path/to/new-file.ts` won't see the file. Run `cone expand /path/to/new-file.ts` (or `git sparse-checkout add /path/to/new-file.ts`) first, then stage normally. The kernel's `expand` route auto-detects file-mode and routes the argument as a pattern.

## 4. Initial cone heuristics

When the user describes a task without giving you paths:

- **Pick the mode first.** Is the file list knowable now? File-mode. Will the agent discover files? Dir-mode. (See §0.)
- **Start small.** A too-narrow cone costs one `expand` to fix. A too-broad cone gives up most of the benefit of using a cone in the first place.
- **Inspect the tree via git metadata.** `git ls-tree -r --name-only HEAD | grep …` and `git log --name-only --all | sort -u | grep …` give you the tree's shape without traversing the filesystem.
- **For file-mode rename surfaces, use full-index search up front.** `git grep -l <symbol> HEAD` enumerates every file containing the symbol, which becomes the cone's file list directly. Pay the one-time breadth cost to get a tight working set.
- **Look at where similar work happened.** `git log --name-only --pretty=format: --all -- '*<keyword>*' | sort -u` shows you which directories historically touch a topic. That's usually a better cone seed than a fresh guess.
- **Confirm when ambiguous.** "Going file-mode with `packages/lib/utils.ts` + the 4 caller files — does that match?" beats spawning twice.

## 5. Parallelising across cones

The canonical scenario: many small, independent tasks, each in its own cone.

For each task:

1. Pick a branch name; if the branch already exists, `cone new` will derive the cone from its diff. Otherwise propose a minimal cone.
2. `cone new <branch> [paths...]`.
3. `cd` into the cone and do the work.
4. Commit. (Push if appropriate.)
5. `cone remove <branch>`.

What makes this work:

- **Isolation by construction.** Each cone is independent. Agent #3 sees and edits only its own cone.
- **Bounded tool results.** `grep`, `find`, glob — all of these stay within the cone in each worktree. Less noise per agent.
- **Cheap teardown.** Removing a cone throws away its working state without touching the primary or other worktrees. If something went wrong, nothing leaks.

To keep the bound:

- **Expand sparingly.** Peek via `git show HEAD:<path>` for reads; reserve `expand` for the moment before an edit.
- **One branch per cone.** Each parallel cone gets its own branch — worktrees can't share a checked-out branch.

## 6. Verifying changes

A cone holds the directories the agent edits. Verification — running tests, linting, building, type-checking — needs the full tree, and happens elsewhere:

- The primary checkout (the original clone you ran `cone new` from)
- A regular `git worktree add` (without sparse-checkout) when you want isolation but the full tree
- CI

The cone covers the edit loop; the primary covers the verification loop. When the user asks to verify a change runs correctly, point them at the primary checkout:

> Your primary checkout is at `$(git worktree list --porcelain | awk '/^worktree/ { print $2; exit }')`. Run the suite there.
