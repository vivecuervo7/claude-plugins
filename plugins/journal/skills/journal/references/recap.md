# Recap Mode

## Parsing

```
/journal recap                        → previous completed week (Mon–Sun)
/journal recap 3                      → last 3 days
/journal recap 7 myproj               → last 7 days, filtered to "myproj"
/journal recap 2026-04-14 2026-04-25  → specific date range
/journal recap 2026-04                → entire month of April 2026
```

Parse the arguments:
- **No args** → the previous completed Monday-to-Sunday week. Use the bundled script to calculate:
  ```bash
  bash ${CLAUDE_SKILL_DIR}/scripts/journal-recap-range.sh
  ```
  It outputs two lines: `from` (Monday) and `to` (Sunday). On a Monday, this recaps the week that just ended yesterday.
- Single number → last N days from today
- Single `YYYY-MM` → from first to last day of that month
- Two `YYYY-MM-DD` dates → explicit from/to range
- A word that isn't a number or date → project filter (can appear after the date args)

## Steps

1. Calculate the date range based on the parsed arguments.
2. Glob for monthly index files in range: `$JOURNAL_ROOT/entries/*/*/index.json`
3. Query entries using the bundled script. Pass all matching index paths (comma-separated) and filters:
   ```bash
   node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js list "path1/index.json,path2/index.json" --from YYYY-MM-DD --to YYYY-MM-DD [--project name]
   ```
   The script returns a JSON array of matching entries sorted by date. Each entry includes a `_path` field with the full filesystem path to the entry file.
4. For a quick overview, use the `summary` field from the list output. Only read full entry files (via `_path`) for entries that are flagged (blog-worthy, demo-worthy, reusable) or need deeper context.
5. Compose a **narrative recap** — not a raw dump. Structure it as:

```markdown
---
type: recap
from: "YYYY-MM-DD"
to: "YYYY-MM-DD"
generated: "YYYY-MM-DD"
project: <project or "all">
entry_count: N
---

## Recap: <from> to <to> [for <project>]

### Highlights
- Key accomplishments and decisions

### By Project
#### <project-name>
- Summary of work done

### Flagged
- Entries tagged blog-worthy, demo-worthy, or reusable
- Pending media hints that haven't been captured

### Open Threads
- Work that seems in-progress or unresolved
```

Adapt the structure to fit the content. Skip empty sections. If there are only a few entries, a simpler format is fine.

## Step 6: Save the recap to disk

Save the compiled recap alongside entries so it can be viewed without recompilation:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-write-entry.sh "$JOURNAL_ROOT/recaps/<from>--<to>.md" << 'EOF'
<recap content>
EOF
```

Where `<from>` and `<to>` are the date range in `YYYY-MM-DD` format. If filtered to a project, use `<from>--<to>--<project>.md`.

If a recap file already exists for the same range and project, overwrite it (the user is regenerating).

## Step 7: Generate HTML and open the recap dashboard

Generate the individual recap HTML, then regenerate the dashboard index and open it:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/journal-recap-html.js "$JOURNAL_ROOT/recaps/<from>--<to>.md"
node ${CLAUDE_SKILL_DIR}/scripts/journal-recap-index.js "$JOURNAL_ROOT" --open
```

The index page shows the latest recap, links to previous weeks, and surfaces blog-worthy entries across all time. Tell the user:
```
Recap saved → recaps/<from>--<to>.md
```

## Step 8: Record the recap date

Update the last-recap timestamp so the nudge system knows:
```bash
echo "$(date +%Y-%m-%d)" > "$JOURNAL_ROOT/.last-recap-date"
```
