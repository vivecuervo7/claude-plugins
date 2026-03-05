# Setup Mode

Runs automatically on first use (when `~/.claude/journal-config.json` doesn't exist), or manually via `/journal setup`.

## Steps

1. Ask the user where to store journal entries:
   - `~/.claude-journal` (Recommended)
   - Custom path

2. Write the pointer file:
   ```bash
   mkdir -p ~/.claude
   ```
   Write `~/.claude/journal-config.json`:
   ```json
   {
     "journal_root": "<chosen-path>"
   }
   ```

3. Create the journal root directory and default config:
   ```bash
   mkdir -p "<chosen-path>/entries"
   ```
   Write `<chosen-path>/config.json`:
   ```json
   {
     "default_recap_days": 7,
     "media_hints_enabled": true,
     "auto_journal_model": "haiku"
   }
   ```

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
Agent(subagent_type="general-purpose", model="<auto_journal_model from config, default haiku>", run_in_background=true,
  prompt="Use the Skill tool to invoke the 'journal' skill, then follow its
  instructions to record: <what was done>")
```

5. Confirm:
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
