---
name: journal
description: "Journal recent work, attach media, or run setup. Dispatches user invocations to the Haiku-pinned journal-append or journal-attach agent, or runs setup inline."
user-invocable: true
argument-hint: "[attach <file> | setup | doctor | <focus text>]"
allowed-tools: Read, Write, Edit, Bash(bash **/journal/*/skills/journal-internal/scripts/*)
---

# Journal

This skill is the user-facing `/journal` entry point. **Its only job is to dispatch.** Do not journal in-line yourself. Do not summarise the user's work. Do not ask clarifying questions. Do not read the playbook — that's the agent's job.

Parse only the **first whitespace-separated token** of `$ARGUMENTS`:

- **First token is `attach`**: call the `journal:journal-attach` agent via the Agent tool. Pass everything after `attach` as the prompt (a file path, optionally followed by a project name). If nothing follows `attach`, tell the user the command needs at least a file path and do not invoke the agent.

- **First token is `setup`**: load the `journal:journal-internal` skill via the Skill tool and follow `references/setup.md`. Setup runs inline because it edits the user's CLAUDE.md, which is a parent-session concern. Typically only run once per machine.

- **First token is `doctor`**: run `bash ${CLAUDE_PLUGIN_ROOT}/skills/journal-internal/scripts/journal-doctor.sh` and relay its checklist output verbatim. No agent involved — this is a read-only diagnostic that confirms pointer file, journal root, config, auto-journal install, and global CLAUDE.md import are all wired up correctly. Add no commentary unless a check fails, in which case quote the remedy line beside the failure.

- **Anything else (including empty `$ARGUMENTS`)**: call the `journal:journal-append` agent via the Agent tool, passing `$ARGUMENTS` verbatim as the prompt. Empty args are fine — the agent handles a no-args append. Free text becomes the entry's focus/annotation.

When an agent returns, relay its confirmation output to the user verbatim, including any "📷 Capture while fresh" media-hint lines for append or the "Attached:" line for attach.

The journaling work itself — entry composition, tag selection, file writes, index updates — happens entirely inside the agent's Haiku context. This skill never sees that logic.
