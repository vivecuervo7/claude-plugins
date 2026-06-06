# journal

An auto-journaling plugin for Claude Code. After significant tasks — decisions, non-obvious solutions, architectural choices, learnings — Claude writes a structured markdown entry for you on Haiku, in a sub-context that doesn't pollute your main session. Entries accumulate as a tagged history you can read directly or hand to a future Claude session to draft a blog post from. Routine work is skipped automatically.

The only command you'll ever need to *remember* is `/journal setup`, once. Manual hooks (`/journal` for focus annotations, `/journal attach` for media when prompted) are escape hatches — the core value is that you don't have to do anything.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install journal@vive-claude
```

### Upgrading from 0.4.x

The agent that auto-journal calls was renamed from `journal-worker` to `journal-append`, and the `/journal recap` and `/journal search` modes were removed. After upgrading, **run `/journal setup` once** — it detects the old auto-journal install in your CLAUDE.md and replaces it with the new template. Existing journal entries are untouched.

## Setup

Run `/journal setup` once. Setup asks where to store entries (default: `~/.claude-journal`) and installs auto-journal instructions into your CLAUDE.md so Claude journals significant work automatically. You can decline the install if you want manual-only behaviour, but the default — and the point of the plugin — is hands-off.

By default, auto-journaling runs in the foreground: the parent session briefly pauses while Haiku writes the entry — usually a few seconds. If you'd rather it run non-blocking, edit your installed `~/.claude/.vive-claude/journal/CLAUDE.md` and add `run_in_background=true` to the `Agent(...)` call. Caveat: background agents in Claude Code cannot prompt for tool permissions, so the agent will silently fail unless the Bash scripts it runs (`journal-context.sh`, `journal-index.js`, etc.) are pre-approved in your `settings.json`. The foreground default is safe everywhere; only switch to background if you've pre-approved those perms.

## How It Works

When auto-journal fires, all you see is a one-line confirmation:

```
Journaled: Added rate limiting to API endpoints → entries/2026/03/05/14-32-my-api.md
  📷 Capture while fresh: rate limiter dashboard showing request throttling
```

Under the hood, the plugin ships two Haiku-pinned agents and one slash command:

- **`journal-append`** writes entries. The main session spawns it after task completion (auto-journal) or when you run `/journal` manually. Either way the parent session doesn't pay for the journaling work — Haiku does.
- **`journal-attach`** attaches a media file to today's entry, invoked via `/journal attach <file>`.
- **`/journal`** is the only user-facing command; it dispatches `attach`, `setup`, or falls through to append.

One entry per project per day — updates refine the existing entry rather than creating duplicates. A tag registry tracks tags by frequency so each new entry reuses existing tags when semantically similar. Tags are the primary navigation mechanism for finding related entries later (when drafting a blog post, for example). See the Storage section for the full layout.

## Manual overrides

The core value is passive — auto-journaling does the work. The commands below exist only for the escape-hatch cases: adding focus to an entry the agent didn't quite frame the way you wanted, attaching media after the fact, or running the one-time setup. A single `/journal` command dispatches by its first argument:

| Command | Description |
|---------|-------------|
| `/journal [focus]` | Manually journal recent work, optionally with text as the focus/annotation (Haiku, via `journal-append`) |
| `/journal attach <file> [project]` | Attach media to today's entry (Haiku, via `journal-attach`) |
| `/journal setup` | Configure storage location and enable auto-journaling (one-time) |
| `/journal doctor` | Diagnostic checklist — confirms pointer file, auto-journal install, and other expected state |

## Storage

Entries live at `~/.claude-journal/` by default. Override during setup or with `CLAUDE_JOURNAL_ROOT`.

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

Each entry is a standalone markdown file with YAML frontmatter — portable and suitable for blog post generation. Media files are stored alongside entries and referenced from the markdown.

`entries/YYYY/MM/index.json` holds a per-entry summary (date, project, tags, summary, file path, media count) for every entry in that month. `tags.json` is a frequency map of every tag in use. The plugin maintains both on every append, by design — they're artefacts for external consumers, not internal infrastructure. A future Claude session drafting a blog post can scan one JSON file instead of opening every entry.

## Tags

Each entry's tags should cover three angles when relevant:

- **Topic / domain** — what the work is about (e.g., `auth`, `rate-limiting`, `journal-plugin`)
- **Tech** — language, framework, or tool involved (e.g., `typescript`, `react`, `playwright`)
- **Kind / signal** — nature or blog/demo potential (e.g., `bugfix`, `refactor`, `architecture`, `exploration`, `blog-worthy`, `demo-worthy`)

The tag registry shows what's already in use; the append agent prefers existing tags when semantically similar to keep the namespace from drifting.

## License

MIT
