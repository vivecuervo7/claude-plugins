# Known Issues

## Background agent permission prompts

**Affected:** Auto-journal (`journal:journal-worker`)

Background agents in Claude Code currently cannot prompt the user for tool permissions. Without pre-approved Bash permissions in `settings.json`, the worker silently fails when trying to run `journal-context.sh` or `journal-index.js`.

**Current status:** `journal-worker` runs as a foreground agent using the `haiku` model to minimise blocking time. Combined with a selective journaling threshold (only journal significant work, not routine tasks), the foreground approach is acceptable.

When Claude Code resolves this limitation, consider restoring background execution:

- `skills/journal/SKILL.md` — add `run_in_background=true` to the Agent snippet
- `skills/journal/references/setup.md` — add `run_in_background=true` to the CLAUDE.md snippet
- `agents/journal-worker.md` — optionally restore `model: sonnet`
