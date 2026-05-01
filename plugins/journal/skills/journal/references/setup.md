# Setup Mode

Runs automatically on first use (when `~/.claude/journal-config.json` doesn't exist), or manually via `/journal setup`.

## Constants

```
TEMPLATE_PATH = ${CLAUDE_PLUGIN_ROOT}/templates/auto-journal.md
INSTALL_DIR   = ~/.claude/.vive-claude/journal
INSTALL_PATH  = ~/.claude/.vive-claude/journal/CLAUDE.md
IMPORT_LINE   = @./.vive-claude/journal/CLAUDE.md
```

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
   - Yes — install the auto-journal instructions (Recommended)
   - No — skip for now

   If yes:
   1. Create `INSTALL_DIR` if it doesn't exist. Read `TEMPLATE_PATH` and write its contents to `INSTALL_PATH`. If `INSTALL_PATH` already exists, overwrite it (this ensures the latest version is installed).
   2. Determine the target CLAUDE.md:
      - If in a git repo with a project-level `CLAUDE.md`, offer to add the import there.
      - Otherwise, add it to `~/.claude/CLAUDE.md` (global).
   3. Check if `IMPORT_LINE` already exists in the target CLAUDE.md. If not, append it on its own line.

5. Ask the user if they want weekly recap reminders:
   - Yes — set `recap_nudge_enabled` to `true` in `<chosen-path>/config.json`
   - No — leave as `false` (default)

   Explain: "When enabled, the journal plugin will check once per day if a recap window has elapsed. If so, it will suggest running `/journal recap`. You can change this anytime in your journal config."

   If yes, use the Edit tool to set `"recap_nudge_enabled": true` in the config file.

6. Confirm:
   ```
   Journal configured → <chosen-path>
   ```
   If auto-journaling was enabled:
   ```
   Auto-journaling enabled → ~/.claude/.vive-claude/journal/CLAUDE.md
   ```
   If recap nudges were enabled:
   ```
   Recap reminders enabled (weekly, Monday morning)
   ```

## Re-running Setup

If running setup again (pointer file already exists), show the current settings and offer to change:
- Storage location (warn that changing does not move existing entries)
- Auto-journaling (enable/disable — re-running with "yes" updates the template to the latest version)
- Recap reminders (enable/disable)

## Migrating from older versions

If the target CLAUDE.md contains either:
- The old inline auto-journal snippet (look for `# Auto-Journal` followed by `Agent(subagent_type="journal:journal-worker"`)
- The intermediate `@./auto-journal.md` import

Remove it and replace with `IMPORT_LINE`. If `~/.claude/auto-journal.md` exists (intermediate version), delete it after installing to the new path.
