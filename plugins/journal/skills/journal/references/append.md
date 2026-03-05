# Append Mode

## Step 1: Detect Project

Already done in "Before Any Mode" via `journal-context.sh`. Use the `project`, `git_repo`, and `project_path` values from that output.

## Step 2: Check for Existing Entry Today

Look for an existing entry for this project today:
```
$JOURNAL_ROOT/entries/YYYY/MM/DD/*-<project>.md
```

Use Glob to check. If found, this is an **update** — read the existing file and note its filename (preserve the original timestamp in the filename).

## Step 3: Compose the Entry

### Frontmatter

```yaml
---
date: "YYYY-MM-DD"
time: "HH:MM"
project: <project-name>
path: <working-directory>
git_repo: true|false
tags: [<relevant-tags>]
# Only include media_hints when blog-worthy/demo-worthy and media_hints_enabled:
media_hints:
  - type: <screenshot|screencast|diagram>
    description: "<what to capture>"
# media is populated by /journal attach — omit if no media attached:
media:
  - file: "media/<filename>"
    description: "<what this shows>"
---
```

Omit `media_hints` and `media` entirely when they have no entries. Do not write empty arrays.

**Tags**: Choose from conventions like `architecture`, `bugfix`, `feature`, `refactor`, `config`, `docs`, `blog-worthy`, `demo-worthy`, `reusable`, `exploration`. Use what fits. Only include `blog-worthy` or `demo-worthy` when the work is genuinely interesting or novel.

**Media hints**: Only include if `media_hints_enabled` is true in config AND the entry has tags like `blog-worthy` or `demo-worthy`. These are prompts for content to capture while context is fresh.

**Media**: Populated by the attach subcommand. Do not add manually during append.

### Body

Write freeform markdown summarising the work done. Guidelines:

- **First paragraph** is the summary — it gets extracted for the index. Make it a clear, standalone description of what was done and why.
- Keep it concise but complete. Short entries (1-2 paragraphs) are fine.
- For `blog-worthy` entries, add richer sections inline:
  - `### Blog Angle` — the hook or counterintuitive insight
  - `### Key Code` — notable code snippets worth highlighting
  - `### Context` — background that would help a reader
- For entries with media hints, add a `### Media Needed` checklist:
  ```markdown
  ### Media Needed
  - [ ] Description of screenshot/screencast/diagram needed
  ```

**If updating an existing entry**: Merge the new work into the existing body. Don't just append — rewrite the body to reflect the full picture of the day's work on this project. Keep the entry coherent as a single narrative.

**If the user provided a note/annotation**: Use it as focus for the entry. The note indicates what the user considers most important about the recent work.

## Step 4: Write the Entry File

Use the Write tool to create/overwrite the file (Write creates parent directories automatically):
- **New entry**: `$JOURNAL_ROOT/entries/YYYY/MM/DD/HH-MM-<project>.md`
- **Update**: Same path as the existing file (preserving original timestamp)

## Step 5: Update Monthly Index

Extract the summary from the **first paragraph** of the body (first line(s) up to the first blank line, truncated to ~120 chars if needed).

Run the bundled index script to upsert the entry:
```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js upsert "$JOURNAL_ROOT/entries/YYYY/MM/index.json" '{"date":"YYYY-MM-DD","time":"HH:MM","project":"<project>","tags":["tag1","tag2"],"summary":"<first paragraph summary>","has_media_hints":false,"media_count":0,"file":"DD/HH-MM-project.md"}'
```

The script handles creating the index file if it doesn't exist and replacing any existing entry with the same `file` value.

## Step 6: Confirm

Use the confirmation format from SKILL.md. For updates, prefix with "Updated:" instead of "Journaled:" and add "(refined existing entry)".
