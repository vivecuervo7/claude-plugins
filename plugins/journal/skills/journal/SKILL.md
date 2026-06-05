---
name: journal
description: "Journal recent work, attach media, run setup, or check install health. The user-facing /journal entry point — dispatches by first argument."
user-invocable: true
argument-hint: "[attach <file> | setup | doctor | <focus text>]"
allowed-tools: Read, Write, Edit, Bash(bash **/journal/*/skills/journal/scripts/*)
---

# Journal

The user-facing `/journal` entry point. Parse only the **first whitespace-separated token** of `$ARGUMENTS` and route:

- **First token is `attach`**: call the `journal:journal-attach` agent via the Agent tool. Pass everything after `attach` as the prompt (a file path, optionally followed by a project name). If nothing follows `attach`, tell the user the command needs at least a file path and do not invoke the agent.

- **First token is `setup`**: follow `references/setup.md` in this skill. Setup runs inline (no agent) because it edits the user's CLAUDE.md and may ask one-time configuration questions — both parent-session concerns. Typically only run once per machine.

- **First token is `doctor`**: run `bash ${CLAUDE_SKILL_DIR}/scripts/journal-doctor.sh` and relay its checklist output verbatim. Read-only diagnostic that confirms pointer file, journal root, config, auto-journal install, and global CLAUDE.md import are all wired up. Add no commentary unless a check fails, in which case quote the remedy line beside the failure.

- **Anything else (including empty `$ARGUMENTS`)**: call the `journal:journal-append` agent via the Agent tool, passing `$ARGUMENTS` verbatim as the prompt. Empty args are fine — the agent handles a no-args append. Free text becomes the entry's focus/annotation.

When an agent returns, relay its confirmation output to the user verbatim, including any "📷 Capture while fresh" media-hint lines for append or the "Attached:" line for attach.

The journaling work itself — entry composition, tag selection, file writes, index updates — happens entirely inside the agent's Haiku context. This dispatch only routes; it never reads the agent's playbook.
