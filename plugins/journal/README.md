# journal

A developer journaling system for Claude Code. Once enabled, Claude automatically journals significant work — decisions, architectural choices, non-obvious solutions, and learnings — without any manual effort. Entries accumulate over time into a tagged history you can read, draft blog posts from, and attach media to.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install journal@vive-claude
```

## Setup

Run `/journal setup` once. Setup asks where to store entries (default: `~/.claude-journal`) and offers to enable auto-journaling. Enabling auto-journaling installs instructions into your CLAUDE.md so that Claude journals automatically after completing significant work. The only visible output is a one-line confirmation:

```
Journaled: Added rate limiting to API endpoints → entries/2026/03/05/14-32-my-api.md
  📷 Capture while fresh: rate limiter dashboard showing request throttling
```

Routine config changes, simple file additions, and mechanical tasks are skipped automatically — only work worth capturing gets journaled.

By default, auto-journaling runs in the foreground (the parent session briefly pauses while Haiku writes the entry — usually a few seconds). If you'd rather it run non-blocking, edit your installed `~/.claude/.vive-claude/journal/CLAUDE.md` and add `run_in_background=true` to the `Agent(...)` call. Background mode requires the agent's Bash invocations to be pre-approved in your `settings.json`, since background agents can't prompt for permissions — see the comment in that file for details.

## How It Works

After completing a task, Claude evaluates whether the work involved decisions, non-obvious solutions, architectural choices, or learnings worth preserving. If so, it spawns a lightweight Haiku-pinned agent (`journal-append`) that writes a structured markdown entry with YAML frontmatter (date, project, tags, media hints). One entry per project per day — updates refine the existing entry rather than creating duplicates.

Manual `/journal` invocations go through the same agent, and `/journal attach <file>` goes through a sibling `journal-attach` agent. Both run on Haiku, so the parent session's model doesn't pay for journaling work.

Monthly index files keep listings fast. A tag registry tracks tags by frequency for consistent tagging across entries. Tags are the primary navigation mechanism — they're how you (or a future Claude session) find related entries when drafting a blog post.

## Commands

The core value is passive — auto-journaling does the work. Commands exist for the manual paths:

A single `/journal` command dispatches by its first argument:

| Command | Description |
|---------|-------------|
| `/journal` | Manually journal recent work (Haiku, via `journal-append`) |
| `/journal <focus>` | Journal recent work with the text as focus/annotation |
| `/journal attach <file> [project]` | Attach media to today's entry (Haiku, via `journal-attach`) |
| `/journal setup` | Configure storage location and enable auto-journaling (one-time) |

## Storage

Entries live at `~/.claude-journal/` by default. Override during setup or with `CLAUDE_JOURNAL_ROOT`.

```
~/.claude-journal/
├── config.json
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

Each entry is a standalone markdown file with YAML frontmatter — portable and suitable for blog post generation. Media files are stored alongside entries and referenced from the markdown.

## Configuration

`~/.claude-journal/config.json` is created automatically on first use:

| Key | Default | Description |
|-----|---------|-------------|
| `media_hints_enabled` | true | Add media capture prompts to blog-worthy/demo-worthy entries |

## Tags

Tags are the primary way to find related entries later. Cover three angles when relevant:

- **Topic / domain** — what the work is about (e.g., `auth`, `rate-limiting`, `journal-plugin`)
- **Tech** — language, framework, or tool involved (e.g., `typescript`, `react`, `playwright`)
- **Kind / signal** — nature or blog/demo potential (e.g., `bugfix`, `refactor`, `architecture`, `exploration`, `blog-worthy`, `demo-worthy`)

Use existing tags when semantically similar — the registry shows what's already in use.

## License

MIT
