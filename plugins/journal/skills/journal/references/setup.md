# Setup Mode

Runs automatically on first use (when `~/.claude/journal-config.json` doesn't exist), or manually via `/journal setup`.

## Steps

1. Ask the user where to store journal entries:
   - `~/.claude-journal` (Recommended)
   - Custom path

2. Write the pointer file using the Write tool (creates parent directories automatically):
   `~/.claude/journal-config.json`:
   ```json
   {
     "journal_root": "<chosen-path>"
   }
   ```

3. Create the journal root config using the Write tool (creates parent directories automatically):
   `<chosen-path>/config.json` — use the default config from SKILL.md "Before Any Mode" step 3.

4. Ask the user if they want to enable auto-journaling:
   - Yes — add the snippet to CLAUDE.md (Recommended)
   - No — skip for now

   If yes, determine the target CLAUDE.md:
   - If in a git repo with a project-level `CLAUDE.md`, offer to add it there.
   - Otherwise, add it to `~/.claude/CLAUDE.md` (global).

   Append the following snippet (do not duplicate if it already exists — check first). Write it with no leading indentation:

```markdown
# Auto-Journal

After completing a task — creating files, fixing a bug, implementing a feature,
scaffolding code, making an architectural decision — journal it. Err on the side
of journalling too much rather than too little. If in doubt, journal it.
Don't interrupt flow — spawn in the background and continue working:
Agent(subagent_type="journal:journal-worker", run_in_background=true,
  prompt="<what was done>")
```

5. If auto-journaling was enabled, inform the user about required permissions:

   ```
   ⚠️  Background auto-journaling requires tool permissions in ~/.claude/settings.json.
   Add these to your permissions.allow array:

     "Read",
     "Write",
     "Edit",
     "Glob",
     "Bash(bash **/vive-claude/journal/*/skills/journal/scripts/*)",
     "Bash(node **/vive-claude/journal/*/skills/journal/scripts/*)"

   Note: Read, Write, Edit, and Glob are global — they apply to all Claude Code
   activity, not just journaling. The Bash patterns are scoped to journal scripts only.
   Without these, background journaling will silently fail.
   Interactive journaling (/journal) works without these permissions.
   ```

   Do NOT modify settings.json automatically. The user should review and add these themselves.

6. Confirm:
   ```
   Journal configured → <chosen-path>
   ```
   If auto-journaling was enabled:
   ```
   Auto-journaling enabled → <CLAUDE.md path>
   ```

## Re-running Setup

If running setup again (pointer file already exists), show the current settings and offer to change:
- Storage location (warn that changing does not move existing entries)
- Auto-journaling (enable/disable, change target CLAUDE.md)
