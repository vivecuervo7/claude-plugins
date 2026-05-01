# journal

A developer journaling system for Claude Code. Once enabled, Claude automatically journals significant work — decisions, architectural choices, non-obvious solutions, and learnings — without any manual effort. Entries accumulate over time into a searchable history you can recap, search, and attach media to.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install journal@vive-claude
```

## Setup

Run `/journal setup` once. Setup asks where to store entries (default: `~/.claude-journal`) and offers to enable auto-journaling. Enabling auto-journaling installs instructions into your CLAUDE.md so that Claude journals in the background after completing significant work. The only visible output is a one-line confirmation:

```
Journaled: Added rate limiting to API endpoints → entries/2026/03/05/14-32-my-api.md
  📷 Capture while fresh: rate limiter dashboard showing request throttling
```

Routine config changes, simple file additions, and mechanical tasks are skipped automatically — only work worth capturing gets journaled.

## How It Works

After completing a task, Claude evaluates whether the work involved decisions, non-obvious solutions, architectural choices, or learnings worth preserving. If so, it spawns a lightweight background agent that writes a structured markdown entry with YAML frontmatter (date, project, tags, media hints). One entry per project per day — updates refine the existing entry rather than creating duplicates.

Monthly index files keep queries fast. A tag registry tracks tags by frequency for consistent tagging across entries.

## Commands

Commands exist for when you want to interact with the journal directly, but the core value is passive.

| Command | Description |
|---------|-------------|
| `/journal` | Manually journal recent work |
| `/journal recap` | Narrative summary of the previous week |
| `/journal recap 3` | Last 3 days |
| `/journal recap 14 myproj` | Last 14 days, filtered to one project |
| `/journal search #blog-worthy` | Search by tag |
| `/journal search "validation"` | Full-text body search |
| `/journal attach ~/Screenshot.png` | Attach media to today's entry |
| `/journal setup` | Change storage location or settings |

## Storage

Entries live at `~/.claude-journal/` by default. Override during setup or with `CLAUDE_JOURNAL_ROOT`.

```
~/.claude-journal/
├── config.json
├── tags.json
├── entries/
│   └── 2026/
│       └── 03/
│           ├── index.json
│           └── 05/
│               ├── 14-32-my-api.md
│               └── media/
│                   └── 14-32-my-api-01.png
└── recaps/
    └── 2026-04-21--2026-04-28.md
```

Each entry is a standalone markdown file with YAML frontmatter — portable and suitable for blog post generation. Media files are stored alongside entries and referenced from the markdown.

## Configuration

`~/.claude-journal/config.json` is created automatically on first use:

| Key | Default | Description |
|-----|---------|-------------|
| `default_recap_days` | 7 | Days to cover in `/journal recap` when no count is given |
| `media_hints_enabled` | true | Add media capture prompts to blog-worthy/demo-worthy entries |
| `recap_nudge_enabled` | false | Show a reminder when a recap window has elapsed |
| `recap_nudge_day` | `"monday"` | Day of week to trigger the recap nudge |
| `recap_nudge_hour` | 8 | Hour (24h) at or after which the nudge fires |

## Tags

Use whatever tags fit. Common conventions:

`architecture` `bugfix` `feature` `refactor` `config` `docs` `blog-worthy` `demo-worthy` `reusable` `exploration`

## License

MIT
