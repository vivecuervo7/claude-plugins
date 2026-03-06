# journal

A developer journaling system for Claude Code. Log work as you go, recap progress, search your history, attach media.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install journal@vive-claude
```

## First Run

On first use, the journal asks where to store entries:

```
Where should journal entries be stored?
1. ~/.claude-journal (Recommended)
2. Custom path
```

Your choice is saved to `~/.claude/journal-config.json`. Run `/journal setup` to change it later.

## Usage

### Log work

```
/journal                    # Journal recent work in the current project
/journal added auth flow     # Journal with a specific focus
```

Claude reviews recent conversation context and writes a structured journal entry. If an entry already exists for the same project today, it updates that entry instead of creating a new one.

### Recap

```
/journal recap              # Last 7 days (default)
/journal recap 3            # Last 3 days
/journal recap 14 myproj    # Last 14 days, one project
```

Produces a narrative summary — highlights, decisions, flagged items, open threads.

### Search

```
/journal search #blog-worthy           # By tag
/journal search my-api             # By project
/journal search 2026-03                # By month
/journal search #architecture myproj   # Combined
```

### Attach media

```
/journal attach ~/Desktop/Screenshot.png             # Attach to today's most recent entry
/journal attach ~/Desktop/Screenshot.png myproj      # Attach to a specific project's entry
```

Copies the file into journal storage, links it in the entry, and checks off any matching media hints. The user never needs to navigate the journal filesystem.

### Reconfigure

```
/journal setup              # Change storage location or auto-journaling settings
```

## Storage

Entries live at `~/.claude-journal/` by default. Override during setup or with `CLAUDE_JOURNAL_ROOT`.

```
~/.claude-journal/
├── config.json
└── entries/
    └── 2026/
        └── 03/
            ├── index.json
            └── 05/
                ├── 14-32-my-api.md
                └── media/
                    └── 14-32-my-api-01.png
```

Each entry is a standalone markdown file with YAML frontmatter. One file per project per day — updates refine the existing entry rather than creating duplicates.

Monthly `index.json` files keep queries fast without a global index.

Media files are stored alongside entries and referenced from the markdown, making entries portable and suitable for blog post generation.

## Configuration

`~/.claude-journal/config.json` is created automatically on first use:

```json
{
  "default_recap_days": 7,
  "media_hints_enabled": true,
  "auto_journal_model": "sonnet"
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `default_recap_days` | 7 | Days to cover in `/journal recap` when no count is given |
| `media_hints_enabled` | true | Add media capture prompts to blog-worthy/demo-worthy entries |
| `auto_journal_model` | `"sonnet"` | Model used for background auto-journaling (`"haiku"`, `"sonnet"`, `"opus"`) |

The pointer file at `~/.claude/journal-config.json` stores only the journal root path.

## Auto-journaling

The plugin doesn't auto-journal by default. Run `/journal setup` to enable it — setup will offer to add the required instructions to your `CLAUDE.md` (global or project-level). This tells Claude to automatically journal completed work in the background.

Auto-journaling runs on a configurable model (see `auto_journal_model` in config). The only visible output is a one-line confirmation. If the entry includes media hints (for blog-worthy or demo-worthy work), they're surfaced as passive reminders:

```
Journaled: Added rate limiting to API endpoints → entries/2026/03/05/14-32-my-api.md
  📷 Capture while fresh: rate limiter dashboard showing request throttling
```

Use `/journal attach` to provide the media when ready.

### Background agent permissions

Auto-journaling uses a background agent, which requires explicit tool permissions in your `~/.claude/settings.json`. Without these, the background agent will silently fail (this is a [known Claude Code limitation](https://github.com/anthropics/claude-code/issues/18172)).

Add the following to your `permissions.allow` array:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Bash(bash **/vive-claude/journal/*/skills/journal/scripts/*)",
      "Bash(node **/vive-claude/journal/*/skills/journal/scripts/*)"
    ]
  }
}
```

**Note:** `Read`, `Write`, `Edit`, and `Glob` are global permissions — they apply to all Claude Code activity, not just the journal plugin. The `Bash` patterns are scoped to the journal's bundled scripts only. Review these permissions and decide what you're comfortable with before adding them. Interactive journaling (`/journal`) does not require these — it runs in the foreground where permissions are prompted normally.

## Entry format

```yaml
---
date: "2026-03-05"
time: "14:32"
project: my-api
path: /home/user/projects/my-api
git_repo: true
tags: [feature, blog-worthy]
media_hints:
  - type: screenshot
    description: "Rate limiter dashboard showing request throttling"
media:
  - file: "media/14-32-my-api-01.png"
    description: "Rate limiter dashboard showing request throttling"
---

Added token-bucket rate limiting to all public API endpoints.
Configurable per-route with sensible defaults (100 req/min).
Chose token-bucket over sliding window for its burst tolerance.

### Blog Angle

Why token-bucket beats sliding window for APIs with bursty
traffic patterns — the math is simpler than you'd expect.

### Media Needed

- [x] Rate limiter dashboard showing request throttling
```

## Tags

Use whatever tags fit. Common conventions:

`architecture` `bugfix` `feature` `refactor` `config` `docs` `blog-worthy` `demo-worthy` `reusable` `exploration`

## License

MIT
