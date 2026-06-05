# Append Mode

Create a new journal entry for the work described in your prompt.

## Step 0: Dedup Against Today's Entries

Before writing anything, glob today's existing entries for this project:

```
$JOURNAL_ROOT/entries/YYYY/MM/DD/*-<PROJECT>.md
```

If any matches exist, read them and compare with your prompt:

- **Fully covered** — every meaningful claim in the prompt is already present in an existing entry. Skip writing. Output:
  ```
  Skipped: nothing new since entries/YYYY/MM/DD/HH-MM-<project>.md
  ```
  Stop here — do not write a new file or touch the index.
- **Partially covered** — some of the prompt is new. Write a new entry covering only the un-captured delta. Don't restate what's already in earlier entries.
- **Nothing covered** — write the entry as-is.

This keeps repeated `/journal` invocations idempotent. Auto-journal invocations rarely hit this (they fire after distinct tasks), but manual invocations often do.

## Step 1: Compose Frontmatter

```yaml
---
date: "YYYY-MM-DD"
time: "HH:MM"
project: <project-name>
path: <project-path>
git_repo: true|false
tags: [<relevant-tags>]
# Only when blog-worthy/demo-worthy AND media_hints_enabled in CONFIG:
media_hints:
  - type: <screenshot|screencast|diagram>
    description: "<what to capture>"
---
```

Use the `DATE`, `TIME`, `PROJECT`, `PROJECT_PATH`, `GIT_REPO` values from bootstrap. Omit `media_hints` entirely when empty — never write an empty array. Do not add a `media` field; that's the attach agent's job.

### Tags

Tags are the primary way future-you finds related entries. Before choosing, read the registry:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js tags "$JOURNAL_ROOT"
```

It returns existing tags ordered by frequency. **Prefer an existing tag** when one covers the concept (e.g. use `scaffolding` rather than coining `scaffold`). Cover three angles when relevant:

- **Topic / domain** — `auth`, `rate-limiting`, `journal-plugin`
- **Tech** — `typescript`, `react`, `playwright`
- **Kind / signal** — `bugfix`, `refactor`, `architecture`, `exploration`, `blog-worthy`, `demo-worthy`

Only mark `blog-worthy` or `demo-worthy` when the work is genuinely novel or interesting.

### Media hints

Include only if `media_hints_enabled` is true in `CONFIG` **and** the entry carries `blog-worthy`/`demo-worthy`. When present, also add a body checklist:

```markdown
### Media Needed
- [ ] Description of what to capture
```

## Step 2: Compose Body

Freeform markdown. The **first paragraph** is extracted into the index — make it a standalone summary of what was done and why. Keep entries concise; 1-2 paragraphs is fine for routine work. Match depth to the prompt — never pad.

For `blog-worthy` entries add inline sections as useful:
- `### Blog Angle` — the hook or counterintuitive insight
- `### Key Code` — notable snippets
- `### Context` — background a reader would need

## Step 3: Write the File

Path: `$JOURNAL_ROOT/entries/YYYY/MM/DD/HH-MM-<project>.md` (Write creates parent dirs).

## Step 4: Update the Monthly Index

Pass the entry JSON on stdin (avoids quoting issues with special chars in the summary):

```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js upsert "$JOURNAL_ROOT/entries/YYYY/MM/index.json" << 'EOF'
{
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "project": "<project>",
  "tags": ["tag1", "tag2"],
  "summary": "<first paragraph, ~120 chars max>",
  "has_media_hints": false,
  "media_count": 0,
  "file": "DD/HH-MM-project.md"
}
EOF
```

## Step 5: Confirm

Use the agent's confirmation format (see agent file).
