# Known Issues

## Background agent permission prompts

**Affected:** Auto-journal (`journal:journal-worker`)

Background agents in Claude Code currently cannot prompt the user for tool permissions. Without pre-approved Bash permissions in `settings.json`, the worker silently fails when trying to run `journal-context.sh` or `journal-index.js`.

**Current workaround:** `journal-worker` runs as a foreground agent using the `haiku` model to minimise blocking time. The original intent was `run_in_background=true`.

When Claude Code resolves this limitation, revert the following:

- `agents/journal-worker.md` — restore `model: sonnet` if desired
- `skills/journal/SKILL.md` — add `run_in_background=true` to the Agent snippet
- `skills/journal/references/setup.md` — same
- User's `~/.claude/CLAUDE.md` — same
