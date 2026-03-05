# Append Mode

## Step 1: Detect Project

Run:
```bash
git rev-parse --show-toplevel 2>/dev/null
```

- If in a git repo: project name = basename of the repo root, `git_repo: true`
- If not: project name = basename of current working directory, `git_repo: false`
- `path` = the current working directory (from `pwd`)

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

```bash
mkdir -p "$JOURNAL_ROOT/entries/YYYY/MM/DD"
```

Write the file:
- **New entry**: `$JOURNAL_ROOT/entries/YYYY/MM/DD/HH-MM-<project>.md`
- **Update**: Same path as the existing file (preserving original timestamp)

Use the Write tool to create/overwrite the file.

## Step 5: Update Monthly Index

Read the existing index at `$JOURNAL_ROOT/entries/YYYY/MM/index.json` (or start with an empty entries array if it doesn't exist).

Extract the summary from the **first paragraph** of the body (first line(s) up to the first blank line, truncated to ~120 chars if needed).

If updating an existing entry, find and replace its record in the index. If new, append.

Write the full index back:

```json
{
  "version": 1,
  "entries": [
    {
      "date": "YYYY-MM-DD",
      "time": "HH:MM",
      "project": "<project>",
      "tags": ["tag1", "tag2"],
      "summary": "<first paragraph summary>",
      "has_media_hints": true,
      "media_count": 0,
      "file": "DD/HH-MM-project.md"
    }
  ]
}
```

## Step 6: Confirm

Output a brief confirmation:
```
Journaled: <summary> → entries/YYYY/MM/DD/HH-MM-project.md
```

If this was an update, note that:
```
Updated: <summary> → entries/YYYY/MM/DD/HH-MM-project.md (refined existing entry)
```
