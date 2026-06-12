# cone discipline

Several patterns govern how the agent should use a cone.

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

Expand the cone only when:

- You're about to make an edit
- You need `rg` / `find` / cone-aware `git grep` to walk across a directory's contents
- The file needs to exist on disk for a tool you're running

## 3. Propose directories

Cone mode is directory-granular. Including `src/auth/login.ts` means including the rest of `src/auth/` along with it — the directory is the unit. When sizing an initial cone, think in directories from the start.

For a task that touches:

- `src/auth/login.ts`
- `src/auth/refresh.ts`
- `src/users/profile.ts`

The cone is `src/auth/ src/users/`.

**Cone mode also auto-includes root-level files of every parent directory along the path.** When you add `apps/web/components/` to your cone, materialisation includes:

- `apps/web/components/` and everything below it (the cone target)
- Root-level files of `apps/web/` (configs, manifests, indices at that level)
- Root-level files of `apps/` (configs at that level)
- Root-level files of the repo (always materialised by cone mode)

So when a top-level file at an intermediate parent is what you need (a workspace-shared utility, a config, a test helper), coning the nested subdirectory you actually edit is enough — the intermediate parent's loose files come along for free, without materialising the parent's other subdirectories.

If a task seems to touch root-level files only (e.g. `index.html`, `about.html`, `package.json`), the cone is **empty** — root files are auto-included by cone mode. `cone new <branch>` with no paths gives you exactly that minimum.

## 4. Initial cone heuristics

When the user describes a task without giving you paths:

- **Start small.** A too-narrow cone costs one `expand` to fix. A too-broad cone gives up most of the benefit of using a cone in the first place.
- **Inspect the tree via git metadata.** `git ls-tree -r --name-only HEAD | grep …` and `git log --name-only --all | sort -u | grep …` give you the tree's shape without traversing the filesystem.
- **Look at where similar work happened.** `git log --name-only --pretty=format: --all -- '*<keyword>*' | sort -u` shows you which directories historically touch a topic. That's usually a better cone seed than a fresh guess.
- **Confirm when ambiguous.** "Spinning up at `src/auth/` and `src/users/` — does that cover what you have in mind?" beats spawning twice.

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
