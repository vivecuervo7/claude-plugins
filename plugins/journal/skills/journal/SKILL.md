---
name: journal
description: "Journal recent work, attach media, run setup, or check install health. The user-facing /journal entry point — dispatches by first argument."
user-invocable: true
argument-hint: "[attach <file> | setup | doctor | <focus text>]"
allowed-tools: Read, Write, Edit, Bash(bash **/journal/*/scripts/*)
---

# Journal

The user-facing `/journal` entry point. Parse the **first whitespace-separated token** of `$ARGUMENTS`, lowercase it, and route:

- **First token is `attach`**: call the `journal:journal-attach` agent via the Agent tool. Pass everything after `attach` as the prompt (a file path, optionally followed by a project name). If nothing follows `attach`, tell the user the command needs at least a file path and do not invoke the agent.

- **First token is `setup`**: follow `references/setup.md` in this skill. Setup runs inline (no agent) because it edits the user's CLAUDE.md and may ask one-time configuration questions — both parent-session concerns. Typically only run once per machine.

- **First token is `doctor`**: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/journal-doctor.sh` and relay its checklist output verbatim. Read-only diagnostic that confirms pointer file, journal root, config, auto-journal install, and global CLAUDE.md import are all wired up. Add no commentary unless a check fails, in which case quote the remedy line beside the failure.

- **Anything else (free text, or empty)**: empty args is a first-class route (manual journal of recent work), not an ambiguity, so there is no AskUserQuestion fallback. The Haiku agent can't see this conversation — only the prompt you pass. **You** must read the conversation and compose a summary of the work worth journaling. That's your only job here; do not run scripts, glob filesystems, or read existing entries (the agent does its own bootstrap and dedups against today's entries before writing).

  - Compose a self-contained prose summary covering decisions, non-obvious solutions, architectural choices, and learnings. Don't hand the agent a one-liner — give it enough substance that it can write a useful entry without seeing the conversation.
  - If `$ARGUMENTS` is non-empty, treat it as focus/annotation — let it shape what you emphasise.
  - Pass the summary as the agent's prompt. The agent decides whether to write, skip (already covered), or write a delta entry, and returns one of:
    - `Journaled: …` (new entry written)
    - `Skipped: nothing new since <existing-file>` (fully covered by today's entries)

When an agent returns, relay its confirmation output to the user verbatim, including any "📷 Capture while fresh" media-hint lines for append or the "Attached:" line for attach.

The journaling work itself — entry composition, tag selection, file writes, index updates — happens entirely inside the agent's Haiku context. This dispatch only routes; it never reads the agent's playbook.
