---
name: journal
description: "Logs work, recaps progress, searches history, and attaches media to a developer journal. Triggers: \"journal this\", \"journal recent work\", \"recap\", \"journal search\", \"journal attach\", \"journal setup\", or needs to record completed tasks, decisions, or progress."
user-invocable: true
argument-hint: "recap, search, attach, setup"
allowed-tools: Read, Write, Edit, Glob, Bash(bash **/vive-claude/journal/*/skills/journal/scripts/*), Bash(node **/vive-claude/journal/*/skills/journal/scripts/*), Bash(bash **/vive-claude/journal/*/skills/journal/scripts/*:*), Bash(node **/vive-claude/journal/*/skills/journal/scripts/*:*)
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

1. **Gather context** by running the bundled script from the skill directory:
   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/journal-context.sh
   ```
   This outputs four lines: `date time` (space-separated on one line), `project`, `git_repo` (true/false), `project_path`. NEVER use your internal clock.

2. **Resolve journal root.** Check in order:
   a. Read `~/.claude/journal-config.json` — if it exists, use its `journal_root` value.
   b. Check env `CLAUDE_JOURNAL_ROOT` — if set, use it.
   c. Fall through to default `~/.claude-journal`.

   If the pointer file does not exist, **read and run `references/setup.md`** before proceeding. This only happens on first use.

3. **Ensure journal root exists.** Use the Read tool to check if `$JOURNAL_ROOT/config.json` exists. If not, use the Write tool to create it (Write creates parent directories automatically):
   ```json
   {
     "default_recap_days": 7,
     "media_hints_enabled": true,
     "auto_journal_model": "haiku"
   }
   ```

4. **Read config** from `$CONFIG_PATH` for settings like `default_recap_days` and `media_hints_enabled`.

5. **Read the resource file** for the determined mode and follow its instructions.

---

## Auto-Journal Behavior

When invoked as a background auto-journal (spawned by the main agent, not by the user running `/journal`):

1. **Use configured model.** The calling agent should spawn with `model: "<config.auto_journal_model>"` (defaults to `"haiku"`).
2. **No user interaction.** Do not ask questions or use AskUserQuestion. Make reasonable choices autonomously.
3. **Minimal output.** One confirmation line when complete.
4. **First-run**: Use default `~/.claude-journal` silently — do not run interactive setup.

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

Run `/journal setup` to enable auto-journaling. Setup will offer to add the required CLAUDE.md snippet automatically.

The snippet spawns the dedicated `journal:journal-worker` agent in the background. This agent has the journal skill preloaded and pre-declared tools, so it runs without permission prompts:

```
Agent(subagent_type="journal:journal-worker", run_in_background=true,
  prompt="<what was done>")
```

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
| `references/setup.md` | First-run config, pointer file, auto-journal snippet | MANDATORY for setup mode |
| `scripts/journal-context.sh` | Date, project, git detection | Run in Before Any Mode step 1 |
| `scripts/journal-index.js` | Index upsert, media increment, filtered list | Run by append, attach, recap, search |
| `scripts/journal-attach.sh` | Media file validation and copy | Run by attach mode |
| `agents/journal-worker.md` | Background auto-journal agent | Spawned by main agent for auto-journaling |

## Keywords

devlog, work log, developer journal, recap, standup, blog-worthy, demo-worthy, progress tracking, media capture
