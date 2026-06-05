# Known Issues

## Background agent permission prompts

**Affected:** Auto-journal (`journal:journal-append`)

Background agents in Claude Code currently cannot prompt the user for tool permissions. Without pre-approved Bash permissions in `settings.json`, the agent silently fails when trying to run `journal-context.sh` or `journal-index.js`.

**Current status:** The `journal-append` agent runs as a **foreground** agent pinned to the Haiku model to minimise blocking time and cost. Combined with a selective journaling threshold (only journal significant work, not routine tasks), the foreground approach is acceptable. The same applies to `journal-attach` (also Haiku, also foreground when invoked manually).

When Claude Code resolves this limitation, consider restoring background execution by adding `run_in_background=true` to the `Agent(...)` call in `templates/auto-journal.md`. User-initiated paths (`/journal`, `/journal attach`) should remain foreground regardless — the user is present to approve any permission prompts and to see the confirmation output.
