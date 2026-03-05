# Attach Mode

Attach media (screenshots, screencasts, diagrams) to a journal entry. The user provides a file path; the skill handles storage and linking.

## Parsing

```
/journal attach <file>              → attach to today's most recent entry
/journal attach <file> myproj       → attach to today's entry for "myproj"
```

The `<file>` can be an absolute path, a relative path, or `~`-prefixed.

## Steps

1. **Resolve the source file.** Expand `~` and verify the file exists using Bash:
   ```bash
   ls -la "<file>"
   ```
   If the file doesn't exist, tell the user and stop.

2. **Find the target entry.** Using today's date:
   - If a project was specified, glob for `$JOURNAL_ROOT/entries/YYYY/MM/DD/*-<project>.md`
   - If not, glob for `$JOURNAL_ROOT/entries/YYYY/MM/DD/*.md` and pick the most recently modified
   - If no entry exists for today, tell the user: "No journal entry found for today. Run `/journal` first."

3. **Get a description.** If the media clearly matches a pending media hint in the entry, use that hint's description automatically. Otherwise, ask the user for a brief (one-line) description of what the media shows.

4. **Copy the file to journal media storage.**
   ```bash
   mkdir -p "$JOURNAL_ROOT/entries/YYYY/MM/DD/media"
   cp "<source>" "$JOURNAL_ROOT/entries/YYYY/MM/DD/media/<entry-stem>-<NN>.<ext>"
   ```
   Where:
   - `<entry-stem>` = the entry filename without `.md` (e.g., `14-32-my-api`)
   - `<NN>` = next sequential number (01, 02, 03...) based on existing media for this entry
   - `<ext>` = original file extension

5. **Read the entry file** and update it:
   - Add to the `media` list in frontmatter:
     ```yaml
     media:
       - file: "media/14-32-my-api-01.png"
         description: "<description>"
     ```
   - If the media matches a media hint, check off the corresponding item in `### Media Needed`:
     ```markdown
     - [x] Description of what was captured
     ```
   - Add a markdown image reference in the body (at the end, or near the relevant section):
     ```markdown
     ![<description>](media/14-32-my-api-01.png)
     ```

6. **Update the monthly index.** Increment `media_count` for the entry.

7. **Confirm:**
   ```
   Attached: <description> → entries/YYYY/MM/DD/media/14-32-my-api-01.png
   ```
