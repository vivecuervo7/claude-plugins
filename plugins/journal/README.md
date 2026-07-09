# journal

An auto-journaling plugin for Claude Code. After significant tasks — decisions, non-obvious solutions, architectural choices, learnings — Claude spawns a Haiku sub-agent to write a structured markdown entry for you. Entries accumulate as a tagged history you can read directly or hand to a future session to draft a blog post from.

Run `/journal setup` once. Everything else is automatic; manual commands exist only as escape hatches.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install journal@vive-claude
```

## Setup

Run `/journal setup` once. Setup asks where to store entries (default: `~/.claude-journal`) and installs auto-journal instructions into your CLAUDE.md. You can decline the install for manual-only behaviour, but hands-off is the point.

By default, auto-journaling runs in the foreground — the parent session pauses for a few seconds while Haiku writes the entry. During setup you can opt into **background mode**: setup installs a small set of scoped permission rules (the journal scripts plus read/write access to your journal root) and switches the installed instructions to a background-aware variant. From then on each auto-journal invocation checks readiness first and runs the append agent in the background when everything's in place — otherwise it falls back to writing the entry in the foreground, so **a journal entry is always written**, never lost to a failed background attempt. `/journal doctor` reports whether background mode is ready and, when it isn't, names exactly which permission rule is missing.

## How it works

```mermaid
flowchart LR
    Task[task completes] --> Append[journal-append · Haiku]
    Append --> Entry[entries/YYYY/MM/DD/<br/>HH-MM-slug.md]
    Append --> Meta[index.json<br/>tags.json]
    Append --> Confirm[one-line<br/>confirmation]
```

What you see in the parent session:

```
Journaled: Added rate limiting to API endpoints → entries/2026/03/05/14-32-my-api.md
  📷 Capture while fresh: rate limiter dashboard showing request throttling
```

| Surface | Role |
|---------|------|
| `journal-append` agent | Writes entries. Spawned automatically after task completion, or manually via `/journal`. |
| `journal-attach` agent | Attaches a media file to today's entry, via `/journal attach <file>`. |
| `/journal` command | Single user-facing dispatcher — falls through to `attach`, `setup`, `doctor`, or `append`. |

Repeated invocations dedup against today's entries: a prompt already fully covered by an existing entry is skipped, while partially-new work gets a fresh *delta* entry covering only what hasn't been captured yet. The append agent prefers existing tags from the registry when semantically similar, keeping the namespace from drifting.

## Commands

| Command | Description |
|---------|-------------|
| `/journal [focus]` | Manually journal recent work, optionally with text as the focus/annotation |
| `/journal attach <file> [project]` | Attach media to today's entry |
| `/journal setup` | Configure storage location and enable auto-journaling (one-time) |
| `/journal doctor` | Diagnostic checklist — confirms pointer file, auto-journal install, and other expected state |

## Storage

Entries live at `~/.claude-journal/` by default. The pointer file written by `/journal setup` (`~/.claude/journal-config.json`) is canonical; the `CLAUDE_JOURNAL_ROOT` environment variable is honoured only as a fallback when no pointer file exists.

```
~/.claude-journal/
├── tags.json
└── entries/
    └── 2026/
        └── 03/
            ├── index.json
            └── 05/
                ├── 14-32-my-api.md
                └── media/
                    └── 14-32-my-api-01.png
```

Each entry is a standalone markdown file with YAML frontmatter — portable and suitable for blog post generation. `entries/YYYY/MM/index.json` holds a per-entry summary (date, project, tags, summary, file path, media count) for every entry in that month. `tags.json` is a frequency map of every tag in use. Both are maintained on every append so external consumers (a future Claude session drafting a blog post, say) can scan one JSON file instead of opening every entry.

The entry markdown files are the source of truth. `index.json` and `tags.json` are rebuildable caches:

```bash
node scripts/journal-index.js sync-index <journal-root> [YYYY/MM]   # rebuild monthly indexes from entry files
node scripts/journal-index.js sync-tags  <journal-root>             # rebuild the tag registry from the indexes
```

**Known limitation:** the index and tag files are updated with an unlocked read-modify-write, so two sessions journaling at the same instant can clobber each other's update to `index.json`/`tags.json`. The entry markdown is never lost; run `sync-index` (then `sync-tags`) to rebuild the caches from disk.

## Tags

Each entry's tags should cover three angles when relevant:

- **Topic / domain** — what the work is about (e.g., `auth`, `rate-limiting`, `journal-plugin`)
- **Tech** — language, framework, or tool involved (e.g., `typescript`, `react`, `playwright`)
- **Kind / signal** — nature or blog/demo potential (e.g., `bugfix`, `refactor`, `architecture`, `exploration`, `blog-worthy`, `demo-worthy`)

## License

MIT
