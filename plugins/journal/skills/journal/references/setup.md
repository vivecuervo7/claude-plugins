# Setup Mode

**Loading**: Loaded by `/journal setup`.

Edits the user's CLAUDE.md and may ask one-time storage questions — both parent-session concerns. Typically run once per machine.

## Constants

```
TEMPLATE_PATH = ${CLAUDE_PLUGIN_ROOT}/templates/auto-journal.md
INSTALL_PATH  = ~/.claude/.vive-claude/journal/CLAUDE.md
IMPORT_LINE   = @./.vive-claude/journal/CLAUDE.md
POINTER_PATH  = ~/.claude/journal-config.json
```

## Steps

1. **Ask where to store entries:** `~/.claude-journal` (recommended) or a custom path. The pointer file is canonical; `CLAUDE_JOURNAL_ROOT` env var is honoured only as a fallback.

2. **Write the pointer file** (`POINTER_PATH`):
   ```json
   { "journal_root": "<chosen-path>" }
   ```

3. **Install auto-journal instructions.** Confirm once, defaulting to yes — auto-journaling is the plugin's main behaviour, and `/journal` is just the manual escape hatch. If continuing:
   1. Read `TEMPLATE_PATH` and write to `INSTALL_PATH` (overwrite if it exists, so re-running picks up plugin updates).
   2. Append `IMPORT_LINE` to `~/.claude/CLAUDE.md` (skip if already present). Auto-journaling is a machine-wide behaviour — do not install into a project-level CLAUDE.md, even when one exists.

4. **Confirm:**
   ```
   Journal configured → <chosen-path>
   Auto-journaling enabled → ~/.claude/.vive-claude/journal/CLAUDE.md
   ```
   (Omit the second line if auto-journaling was declined.)

## Re-running

If the pointer file already exists, show current settings and offer to change the storage location (warn: doesn't move existing entries) or reinstall the template.
