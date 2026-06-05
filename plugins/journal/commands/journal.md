---
description: Journal recent work, attach media, or run setup
argument-hint: "[attach <file> | setup | <focus text>]"
---

Dispatch the user's `/journal` invocation based on `$ARGUMENTS`. Parse only the **first whitespace-separated token**:

- **First token is `attach`**: call the `journal:journal-attach` agent via the Agent tool. Pass everything after `attach` as the prompt (the file path, optionally followed by a project name). If nothing follows `attach`, tell the user the command needs at least a file path and do not invoke the agent.

- **First token is `setup`**: load the `journal:journal-internal` skill via the Skill tool and follow `references/setup.md`. This runs in the current session (not via an agent) because setup edits the user's CLAUDE.md, which is a parent-session concern. Typically only run once per machine.

- **Anything else (including empty `$ARGUMENTS`)**: this is an **append** invocation. Call the `journal:journal-append` agent via the Agent tool, passing `$ARGUMENTS` verbatim as the prompt. Empty args are fine — the agent handles a no-args append. Free text is treated as the focus/annotation for the entry.

When an agent returns, relay its confirmation output to the user verbatim (including any "📷 Capture while fresh" media hint lines for append, or the "Attached:" line for attach).

Do nothing else: do not journal in-line yourself, do not summarise the user's work before dispatching, do not ask clarifying questions.
