---
name: journal
description: "Logs work, recaps progress, searches history, and attaches media to a developer journal. Triggers: \"journal this\", \"journal recent work\", \"recap\", \"journal search\", \"journal attach\", \"journal setup\", or needs to record completed tasks, decisions, or progress."
user-invocable: true
argument-hint: "recap, search, attach, setup"
allowed-tools: Read, Write, Edit, Glob, Bash(bash */scripts/*), Bash(node */scripts/*)
---

# Journal

Record development work, recap progress, search history, and attach media. Route by subcommand.

## Routing

Parse the user's input to determine the mode:

| Input | Mode | Resource |
|---|---|---|
| `/journal` (no args) | **Append** — journal recent work | `references/append.md` |
| `/journal some text here` | **Append** — journal with the text as focus/annotation | `references/append.md` |
| `/journal recap [N] [project]` | **Recap** — narrative summary of last N days | `references/recap.md` |
| `/journal search <query>` | **Search** — find entries by tag, project, or date | `references/search.md` |
| `/journal attach <file> [project]` | **Attach** — attach media to a journal entry | `references/attach.md` |
| `/journal setup` | **Setup** — configure journal storage location | `references/setup.md` |

After determining the mode, **Read the corresponding resource file** (MANDATORY — load exactly one based on the routed mode) from the skill directory and follow its instructions. Do not proceed without reading the mode file.

---

## Constants

```
POINTER_PATH = ~/.claude/journal-config.json
```

The pointer file contains `{ "journal_root": "<path>" }` and is the single source of truth for where journal data lives.

```
JOURNAL_ROOT = read from POINTER_PATH, or env CLAUDE_JOURNAL_ROOT, or ~/.claude-journal
CONFIG_PATH  = $JOURNAL_ROOT/config.json
```

---

## Before Any Mode

Run **only the steps needed** for the determined mode. Minimise tool calls.

| Step | Append | Attach | Recap | Search | Setup |
|------|--------|--------|-------|--------|-------|
| 1. Entry context | Yes | Yes | — | — | — |
| 2. Journal root | Yes | Yes | Yes | Yes | Yes |
| 3. Config | Yes | Yes | Yes | Yes | — |

**Step 1 — Entry context** (append + attach only):
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-context.sh
```
Outputs four lines: `YYYY-MM-DD HH:MM`, project name, git status (`true`/`false`), working directory. NEVER use your internal clock for the date.

**Step 2 — Resolve journal root:**
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-root.sh
```
If the pointer file does not exist (first interactive run), **read and run `references/setup.md`** before proceeding.

**Step 3 — Ensure config exists and read it:**
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-config.sh "$JOURNAL_ROOT"
```
Creates `$JOURNAL_ROOT/config.json` with defaults if missing, then outputs its content.

After completing the relevant steps, **read the resource file** for the determined mode and follow its instructions.

---

## Auto-Journal Behavior

When invoked as a background auto-journal (spawned by the main agent, not by the user running `/journal`):

1. **No user interaction.** Do not ask questions or use AskUserQuestion. Make reasonable choices autonomously.
2. **Minimal output.** One confirmation line when complete.
3. **First-run**: Use default `~/.claude-journal` silently — do not run interactive setup.
4. **Proportional depth.** Match entry depth to the significance of the work. Rich context from the main agent (decisions, architecture, learnings) warrants a detailed entry with sections. A thin prompt about routine work warrants a brief 1-2 paragraph entry. Do not pad thin work into long entries.

### Confirmation Format

```
Journaled: <summary> → entries/YYYY/MM/DD/HH-MM-project.md
```

With media hints:
```
Journaled: <summary> → entries/YYYY/MM/DD/HH-MM-project.md
  📷 Capture while fresh: <media hint description>
```

### Enabling Auto-Journal

Run `/journal setup` to enable auto-journaling. Setup installs the plugin's `templates/auto-journal.md` to `~/.claude/.vive-claude/journal/CLAUDE.md` and adds an `@./.vive-claude/journal/CLAUDE.md` import to the user's CLAUDE.md. Re-running setup updates the template to the latest version.

---

## Edge Cases

- **First ever journal (interactive)**: Run setup to ask where to store entries, then proceed.
- **First ever journal (background/auto)**: Use default `~/.claude-journal` silently. Create directory structure and config automatically.
- **No entries in range**: Say so clearly. Don't fabricate content.
- **Very long entry body on update**: Keep total entry under ~200 lines. Summarise older work if needed to stay concise.
- **Multiple projects same day**: Each project gets its own file. No conflicts.
- **Project name with special chars**: Sanitise to lowercase alphanumeric + hyphens for the filename.
- **Attach with no entry today**: Tell the user to run `/journal` first.
- **Attach matches media hint**: Auto-fill the description from the hint and check it off.

## References

| File | Contents | When to load |
|------|----------|--------------|
| `references/append.md` | Entry composition, frontmatter schema, index upsert | MANDATORY for append mode |
| `references/recap.md` | Date range querying, narrative recap structure | MANDATORY for recap mode |
| `references/search.md` | Query parsing, index search, results formatting | MANDATORY for search mode |
| `references/attach.md` | Media copy, frontmatter linking, index media increment | MANDATORY for attach mode |
| `references/setup.md` | First-run config, pointer file, auto-journal import | MANDATORY for setup mode |
| `templates/auto-journal.md` | Auto-journal CLAUDE.md instructions (installed to ~/.claude/) | Setup mode step 4 |
| `scripts/journal-date.sh` | Current date/time | Before Any Mode step 1 |
| `scripts/journal-project.sh` | Sanitized project name from cwd | Before Any Mode step 1 |
| `scripts/journal-git.sh` | Git repo status and project path | Before Any Mode step 1 |
| `scripts/journal-root.sh` | Resolved journal root path | Before Any Mode step 2 |
| `scripts/journal-config.sh` | Ensure config exists, output values | Before Any Mode step 3 |
| `scripts/journal-find-entry.sh` | Find existing entry for today | Append mode step 2 |
| `scripts/journal-read-entry.sh` | Read existing entry content | Append mode step 2 |
| `scripts/journal-write-entry.sh` | Write entry file from stdin | Append mode step 4 |
| `scripts/journal-index.js` | Index upsert, media increment, filtered list | Append, attach, recap, search |
| `scripts/journal-recap-range.sh` | Calculate previous completed week (Mon–Sun) | Recap mode (no-args default) |
| `scripts/journal-recap-html.js` | Generate styled HTML for a single recap | Recap mode step 7 |
| `scripts/journal-recap-index.js` | Generate recap dashboard (index.html) with all recaps and flagged entries | Recap mode step 7 |
| `scripts/journal-search-text.sh` | Full-text grep across entry bodies | Search mode (text queries) |
| `scripts/journal-recap-check.sh` | Check if recap nudge is due | PreToolUse hook (once per day) |
| `scripts/journal-attach.sh` | Media file validation and copy | Attach mode |
| `agents/journal-worker.md` | Background auto-journal agent | Spawned by main agent for auto-journaling |

## Keywords

devlog, work log, developer journal, recap, standup, blog-worthy, demo-worthy, progress tracking, media capture
