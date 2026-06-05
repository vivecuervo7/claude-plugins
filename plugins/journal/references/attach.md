# Attach Mode

Attach a media file (screenshot, screencast, diagram) to a journal entry.

Prompt format: `<file>` or `<file> <project>`. The file path may be absolute, relative, or `~`-prefixed.

## Steps

1. **Find the target entry** using today's `DATE`:
   - With a project arg: glob `$JOURNAL_ROOT/entries/YYYY/MM/DD/*-<project>.md`
   - Without: glob `$JOURNAL_ROOT/entries/YYYY/MM/DD/*.md` and pick the most recently modified
   - If no entry exists for today, emit the no-entry message and stop.

2. **Get a description.** If the file clearly matches a pending media hint in the entry, reuse that hint's description. Otherwise ask the user for a one-line description.

3. **Copy the file** into journal storage:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/journal-attach.sh "<source>" "$JOURNAL_ROOT/entries/YYYY/MM/DD/media" "<entry-stem>-<NN>.<ext>"
   ```
   - `<entry-stem>` = entry filename without `.md` (e.g. `14-32-my-api`)
   - `<NN>` = next sequential index (01, 02, …) based on existing media for this entry
   - `<ext>` = the source file's extension
   The script errors if the source is missing — relay that and stop.

4. **Update the entry file.** Add to `media` in frontmatter:
   ```yaml
   media:
     - file: "media/14-32-my-api-01.png"
       description: "<description>"
   ```
   If the file matched a media hint, tick its checkbox in `### Media Needed`. Add an image reference in the body:
   ```markdown
   ![<description>](media/14-32-my-api-01.png)
   ```

5. **Increment media count in the index:**
   ```bash
   node ${CLAUDE_PLUGIN_ROOT}/scripts/journal-index.js increment-media "$JOURNAL_ROOT/entries/YYYY/MM/index.json" "DD/HH-MM-project.md"
   ```

6. **Confirm** using the agent's format.
