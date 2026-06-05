---
name: journal-internal
description: "Internal playbook for the journal plugin. Loaded by the journal-append and journal-attach agents (Haiku). Not user-invocable."
user-invocable: false
allowed-tools: Read, Write, Edit, Glob, Bash(bash **/journal/*/skills/journal-internal/scripts/*), Bash(node **/journal/*/skills/journal-internal/scripts/*)
---

# Journal (Internal Playbook)

Shared playbook for the append and attach agents. Each agent loads its own reference: `journal-append` → `references/append.md`, `journal-attach` → `references/attach.md`.

## Before Any Mode

Run the bootstrap script once. It emits all context as `KEY=VALUE` lines:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-bootstrap.sh
```

Output keys: `DATE`, `TIME`, `PROJECT`, `PROJECT_PATH`, `GIT_REPO`, `JOURNAL_ROOT`, `CONFIG` (single-line JSON). Use these throughout the mode — **never use your internal clock** for the date.

On first run the script silently creates `~/.claude-journal` and writes a default `config.json`. Interactive setup is the separate `/journal setup` flow.

Then read your mode's reference file and follow it.
