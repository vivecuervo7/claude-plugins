# cone

Spin up cones — minimal git worktrees with sparse-checkout that materialise only the directories Claude needs to edit. Expand the cone on demand, tear it down when done.

The name comes from git's own `sparse-checkout --cone` mode. Each cone is a sparse worktree: a second working directory backed by the same `.git`, with only the directories you asked for visible on disk.

A cone is scoped for editing. Claude reads files, makes changes, commits — verification (builds, tests, linters) runs from your primary checkout, where the full tree is available.

## When this is worth it

You have ten tickets in your backlog. They're all small — typo fixes in a static site, copy tweaks across blog posts, copy changes scattered through a docs tree, a handful of independent bug reports. They're independent enough to parallelise: ten Claude agents, ten cones, ten PRs.

With cones, each agent gets a 5-file slice of your 5,000-file repo. Its tool results are bounded to the surface it actually needs. The cone is the agent's edit surface — files outside it stay in git's object store and off disk. Teardown is one command.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install cone@vive-claude
```

## Commands

| Command | What it does |
|---------|--------------|
| `/cone new <branch> [paths...]` | Create a cone on `<branch>`. Behaviour depends on the inputs — see below. |
| `/cone expand <paths...>` | Add directories to the current cone. Idempotent. |
| `/cone list` | List all worktrees with their branches and current cones. |
| `/cone remove <name-or-path> [--force]` | Tear down a cone. Refuses on uncommitted changes unless `--force`. |
| `/cone doctor` | Verify git version and repo state support sparse worktrees. |

`/cone new` behaves four ways depending on whether the branch already exists and whether you pass paths:

| Inputs | Result |
|--------|--------|
| Branch is new, no paths | Branch created off `HEAD`. Cone is root files only. |
| Branch is new, paths given | Branch created off `HEAD`. Cone is those directories. |
| Branch exists, no paths | Branch checked out. Cone derived from `git diff <base>...<branch>` (base = `main`/`master`/`origin/HEAD`). |
| Branch exists, paths given | Branch checked out. Cone is the explicit paths. |

The skill also responds to natural phrasing — "spin up a cone for the auth refactor in `src/auth/`", "narrow this work to the docs tree", "give me a cone for the changes on `feat/foo`".

## How it works

A git worktree is a second working directory backed by the same `.git`. Sparse-checkout in cone mode tells git to only materialise the directories you ask for, plus the repo root. Together: a tiny working tree sitting next to your primary checkout, sharing object storage but isolated in working state. You can spawn many of them in parallel without disk explosion.

The cone is **directory-granular**. You can include `src/auth/` but not "just `src/auth/login.ts`". The smallest unit is a directory. If a task seems to touch root-level files only, the cone is empty — `/cone new <branch>` with no paths gives you that minimum.

## Two patterns the skill enforces

**Peek before expanding.** If the agent needs to read a file outside its cone, the right move is `git show HEAD:path/to/file` — that reads from git's object store without materialising. Expanding the cone is permanent within the session and broadens the agent's working set. Only expand when about to edit.

**Propose directories, not files.** Cone mode is directory-granular. The skill asks the agent to think in directories from the outset.

## When this is *not* worth it

- **Small repos.** Under a few hundred files, the overhead outweighs the win.
- **You need to verify the change runs.** Builds, tests, linters, and type-checkers expect the full tree — those belong in your primary checkout (or a regular non-sparse worktree).
- **The change spreads broadly.** If your cone ends up covering half the repo, you've lost the win. Stay in the primary.

## License

MIT
