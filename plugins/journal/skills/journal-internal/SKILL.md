---
name: journal-internal
description: "Internal playbook for the journal plugin. Loaded by the journal-append and journal-attach agents (Haiku) and by the /journal setup flow. Not user-invocable directly."
user-invocable: false
allowed-tools: Read, Write, Edit, Glob, Bash(bash */scripts/*), Bash(node */scripts/*)
---

# Journal (Internal Playbook)

Shared playbook for the append and attach agents. Each invoking agent has a fixed mode declared in its own frontmatter; load that mode's reference and follow it: `journal-append` → `references/append.md`, `journal-attach` → `references/attach.md`. Setup is a third entrypoint — loaded directly by `/journal setup` in the parent session (no agent), see `references/setup.md`.

Not user-invocable. Users reach this functionality through the `/journal` slash command (a separate user-invocable skill), which dispatches by its first argument and calls the appropriate agent. This skill is the agent's playbook, not the user's entry point.

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

Run all three steps regardless of mode (append and attach both need entry context and config).

**Step 1 — Entry context:**
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-context.sh
```
Outputs four lines: `YYYY-MM-DD HH:MM`, sanitised project name, git status (`true`/`false`), project path (git toplevel when in a repo, otherwise cwd). NEVER use your internal clock for the date.

**Step 2 — Resolve journal root:**
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-root.sh
```
If the pointer file does not exist (first run), use `~/.claude-journal` as the default and create the directory structure silently. Do not invoke interactive setup — that's `/journal setup`'s job.

**Step 3 — Ensure config exists and read it:**
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-config.sh "$JOURNAL_ROOT"
```
Creates `$JOURNAL_ROOT/config.json` with defaults if missing, then outputs its content.

After completing these steps, **read the resource file** for your mode and follow its instructions.

---

## Edge Cases

- **First ever journal**: Use default `~/.claude-journal` silently. Create directory structure and config automatically. Interactive setup is a separate `/journal setup` flow.
- **Very long entry body on update**: Keep total entry under ~200 lines. Summarise older work if needed to stay concise.
- **Multiple projects same day**: Each project gets its own file. No conflicts.
- **Project name with special chars**: Sanitise to lowercase alphanumeric + hyphens for the filename.
- **Attach with no entry today**: Tell the user to run `/journal` first.
- **Attach matches media hint**: Auto-fill the description from the hint and check it off.

## References

| File | Contents | When to load |
|------|----------|--------------|
| `references/append.md` | Entry composition, frontmatter schema, index upsert | MANDATORY for append mode |
| `references/attach.md` | Media copy, frontmatter linking, index media increment | MANDATORY for attach mode |
| `references/setup.md` | First-run config, pointer file, auto-journal import | Loaded by `/journal setup` in parent session |
| `templates/auto-journal.md` | Auto-journal CLAUDE.md instructions (installed to ~/.claude/) | Setup step |
| `scripts/journal-context.sh` | Date/time, sanitised project name, git status, project path | Before Any Mode step 1 |
| `scripts/journal-root.sh` | Resolved journal root path | Before Any Mode step 2 |
| `scripts/journal-config.sh` | Ensure config exists, output values | Before Any Mode step 3 |
| `scripts/journal-find-entry.sh` | Find existing entry for today | Append mode |
| `scripts/journal-read-entry.sh` | Read existing entry content | Append mode |
| `scripts/journal-write-entry.sh` | Write entry file from stdin | Append mode |
| `scripts/journal-index.js` | Index upsert, media increment, tag list, tag sync (recovery) | Append, attach |
| `scripts/journal-attach.sh` | Media file validation and copy | Attach mode |
| `agents/journal-append.md` | Append agent (Haiku) | Invoked by auto-journal and `/journal` |
| `agents/journal-attach.md` | Attach agent (Haiku) | Invoked by `/journal attach` |

## Keywords

devlog, work log, developer journal, progress tracking, media capture
