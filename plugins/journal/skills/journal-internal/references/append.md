# Append Mode

## Step 1: Detect Project

Already done in "Before Any Mode". Use the `date`, `time`, `project`, `git_repo`, and `project_path` values from `journal-context.sh`.

## Step 2: Check for Existing Entry Today

Use the Glob tool to look for an existing entry for this project today:

```
$JOURNAL_ROOT/entries/YYYY/MM/DD/*-<project>.md
```

If Glob returns a path, this is an **update** — use the Read tool to load the existing content and note the filename (preserve the original timestamp). If Glob returns no matches, this is a new entry.

## Step 3: Compose the Entry

### Frontmatter

```yaml
---
date: "YYYY-MM-DD"
time: "HH:MM"
project: <project-name>
path: <project-path>
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

**Tags**: Tags are the *primary* way future-you (and a future Claude session drafting a blog post) finds related entries. Be deliberate. Before choosing tags, read the tag registry:
```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js tags "$JOURNAL_ROOT"
```
This returns existing tags ordered by frequency (most-used first). **Prefer existing tags** when a candidate is semantically similar — e.g., if `scaffolding` exists, use it instead of `scaffold`; if `testing` exists, use it instead of `test`. New tags are fine when genuinely novel (no similar existing tag covers the concept). Cover three angles when relevant:
- **Topic / domain** — what the work is about (e.g., `auth`, `rate-limiting`, `journal-plugin`)
- **Tech** — language, framework, or tool involved (e.g., `typescript`, `react`, `playwright`)
- **Kind / signal** — nature of the work or its blog/demo potential (e.g., `bugfix`, `refactor`, `architecture`, `exploration`, `blog-worthy`, `demo-worthy`)

Only include `blog-worthy` or `demo-worthy` when the work is genuinely interesting or novel. Thin or routine entries should not carry those signals.

**Media hints**: Only include if `media_hints_enabled` is true in config AND the entry has tags like `blog-worthy` or `demo-worthy`. These are prompts for content to capture while context is fresh.

**Media**: Populated by the attach subcommand. Do not add manually during append.

### Body

Write freeform markdown summarising the work done. Guidelines:

- **First paragraph** is the summary — it gets extracted for the index. Make it a clear, standalone description of what was done and why.
- Keep it concise but complete. Short entries (1-2 paragraphs) are fine. Target this level of detail:
  > Implemented token-bucket rate limiting on all public API endpoints. Chose token-bucket over sliding window for burst tolerance. Configurable per-route, defaulting to 100 req/min.
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

Use the Write tool to write the composed entry. The Write tool creates parent directories automatically, so no `mkdir` step is needed.

- **New entry path**: `$JOURNAL_ROOT/entries/YYYY/MM/DD/HH-MM-<project>.md`
- **Update path**: Same as the existing file (preserving original timestamp)

## Step 5: Update Monthly Index

Extract the summary from the **first paragraph** of the body (first line(s) up to the first blank line, truncated to ~120 chars if needed).

Run the bundled index script to upsert the entry. The script reads the JSON entry from stdin to avoid shell-quoting issues with summaries that contain single quotes, backslashes, or other special characters:
```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js upsert "$JOURNAL_ROOT/entries/YYYY/MM/index.json" << 'EOF'
{
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "project": "<project>",
  "tags": ["tag1", "tag2"],
  "summary": "<first paragraph summary>",
  "has_media_hints": false,
  "media_count": 0,
  "file": "DD/HH-MM-project.md"
}
EOF
```

The script creates the index file if it doesn't exist and replaces any existing entry with the same `file` value. The quoted heredoc (`'EOF'`) prevents shell expansion inside the JSON.

## Step 6: Confirm

Use the confirmation format from SKILL.md. For updates, prefix with "Updated:" instead of "Journaled:" and add "(refined existing entry)".
