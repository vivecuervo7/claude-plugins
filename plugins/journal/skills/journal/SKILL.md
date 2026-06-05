---
name: journal
description: "Logs work and attaches media to a developer journal. Loaded by the journal-append and journal-attach agents (Haiku); not user-invocable directly."
user-invocable: false
allowed-tools: Read, Write, Edit, Glob, Bash(bash */scripts/*), Bash(node */scripts/*)
---

# Journal

Shared playbook for append and attach modes. Loaded by the `journal-append` agent (append) and the `journal-attach` agent (attach). Not user-invocable directly — users reach this functionality through the single `/journal` slash command, which dispatches by its first argument: `attach <file>` → attach agent, `setup` → load `references/setup.md` in the parent session, anything else → append agent.

## Routing

The invoking agent already knows its mode. Load the corresponding reference and follow it:

| Invoking agent | Mode | Resource |
|---|---|---|
| `journal-append` | **Append** — journal recent work | `references/append.md` |
| `journal-attach` | **Attach** — attach media to a journal entry | `references/attach.md` |

Both agents are invoked by the single `/journal` slash command, which dispatches by the first argument token (`attach` → attach agent, anything else → append agent).

Setup is handled differently: `/journal setup` loads `references/setup.md` directly in the parent session (no agent — it edits the user's CLAUDE.md, runs once per machine).

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
Outputs four lines: `YYYY-MM-DD HH:MM`, project name, git status (`true`/`false`), working directory. NEVER use your internal clock for the date.

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
| `scripts/journal-context.sh` | Date/time, project, git status, working dir | Before Any Mode step 1 |
| `scripts/journal-root.sh` | Resolved journal root path | Before Any Mode step 2 |
| `scripts/journal-config.sh` | Ensure config exists, output values | Before Any Mode step 3 |
| `scripts/journal-find-entry.sh` | Find existing entry for today | Append mode |
| `scripts/journal-read-entry.sh` | Read existing entry content | Append mode |
| `scripts/journal-write-entry.sh` | Write entry file from stdin | Append mode |
| `scripts/journal-index.js` | Index upsert, media increment, tag list | Append, attach |
| `scripts/journal-attach.sh` | Media file validation and copy | Attach mode |
| `agents/journal-append.md` | Append agent (Haiku) | Invoked by auto-journal and `/journal` |
| `agents/journal-attach.md` | Attach agent (Haiku) | Invoked by `/journal attach` |

## Keywords

devlog, work log, developer journal, progress tracking, media capture
