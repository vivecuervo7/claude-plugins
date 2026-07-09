# Setup Mode

**Loading**: Loaded by `/journal setup`.

Edits the user's CLAUDE.md and may ask one-time storage questions — both parent-session concerns. Typically run once per machine.

## Constants

```
TEMPLATE_PATH            = ${CLAUDE_PLUGIN_ROOT}/templates/auto-journal.md
TEMPLATE_BACKGROUND_PATH = ${CLAUDE_PLUGIN_ROOT}/templates/auto-journal-background.md
INSTALL_PATH             = ~/.claude/.vive-claude/journal/CLAUDE.md
IMPORT_LINE              = @./.vive-claude/journal/CLAUDE.md
POINTER_PATH             = ~/.claude/journal-config.json
```

`INSTALL_PATH` and the `journal:journal-append` sentinel are duplicated in
`scripts/journal-doctor.sh` and the `templates/auto-journal*.md` files — keep them in sync.

## Steps

1. **Ask where to store entries:** `~/.claude-journal` (recommended) or a custom path. The pointer file is canonical; `CLAUDE_JOURNAL_ROOT` env var is honoured only as a fallback.

2. **Write the pointer file** (`POINTER_PATH`):
   ```json
   { "journal_root": "<chosen-path>" }
   ```

3. **Install auto-journal instructions.** Confirm once, defaulting to yes — auto-journaling is the plugin's main behaviour, and `/journal` is just the manual escape hatch. If continuing:
   1. Read `TEMPLATE_PATH` and write to `INSTALL_PATH` (overwrite if it exists, so re-running picks up plugin updates).
   2. Append `IMPORT_LINE` to `~/.claude/CLAUDE.md` (skip if already present). Auto-journaling is a machine-wide behaviour — do not install into a project-level CLAUDE.md, even when one exists.
   3. Record the choice in the pointer file so `/journal doctor` can distinguish "declined by choice" from "broken install": set `"auto_journal": true` when installed, `"auto_journal": false` when the user declines. The pointer file becomes:
      ```json
      { "journal_root": "<chosen-path>", "auto_journal": true|false }
      ```

4. **Offer background mode** (only when the install in step 3 was accepted). Ask "Run auto-journaling in the background?" — recommend yes; hands-free journaling is the point. Background is an invoke-time optimisation with an automatic foreground fallback: every invocation checks readiness and writes the entry either way, so journaling is never lost to a failed background attempt. If accepted:
   1. Merge these rules into `permissions.allow` in `~/.claude/settings.json` — read the file, merge, write it back: preserve every existing rule, skip any already present, and create the file and the `permissions`/`allow` keys if missing.
      ```
      Bash(bash **/journal/*/scripts/*)
      Bash(bash **/journal/scripts/*)
      Bash(node **/journal/*/scripts/*)
      Bash(node **/journal/scripts/*)
      Read(<ROOT>/**)
      Write(<ROOT>/**)
      Edit(<ROOT>/**)
      ```
      `<ROOT>` is the chosen journal root as a permission pattern: home-relative (`~/.claude-journal`) when it lives under `$HOME`, otherwise an absolute pattern with a leading `//` (e.g. `//srv/journal`).
   2. Install the background template variant: read `TEMPLATE_BACKGROUND_PATH`, replace the `{{PLUGIN_ROOT}}` placeholder with the resolved value of `${CLAUDE_PLUGIN_ROOT}`, and write the result to `INSTALL_PATH` (overwriting the foreground copy from step 3.1). This variant runs `journal-ready.sh` at journal time and only spawns the agent in the background when it reports ready, falling back to foreground otherwise.
   3. Record `"background": true` in the pointer file (`"background": false` when declined). The pointer file becomes:
      ```json
      { "journal_root": "<chosen-path>", "auto_journal": true, "background": true|false }
      ```
   Declining leaves the plain foreground template from step 3.1 in place. Re-running setup and declining background restores it — re-write `INSTALL_PATH` from `TEMPLATE_PATH`.

5. **Confirm:**
   ```
   Journal configured → <chosen-path>
   Auto-journaling enabled → ~/.claude/.vive-claude/journal/CLAUDE.md
   Background mode enabled → permissions installed in ~/.claude/settings.json
   ```
   (Omit the second line if auto-journaling was declined; omit the third if background mode was declined.)

## Re-running

If the pointer file already exists, show current settings — including auto-journal and background state — and offer to change the storage location (warn: doesn't move existing entries), reinstall the template, or toggle background mode (which installs the matching template variant — background-aware or plain foreground — and adds or removes the scoped permission rules).
