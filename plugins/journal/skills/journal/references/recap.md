# Recap Mode

## Parsing

```
/journal recap           → last N days (from config default_recap_days)
/journal recap 3         → last 3 days
/journal recap 7 myproj  → last 7 days, filtered to "myproj"
```

## Steps

1. Calculate the date range: from (today - N days) to today.
2. Glob for monthly index files in range: `$JOURNAL_ROOT/entries/*/*/index.json`
3. Query entries using the bundled script. Pass all matching index paths (comma-separated) and filters:
   ```bash
   node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js list "path1/index.json,path2/index.json" --from YYYY-MM-DD --to YYYY-MM-DD [--project name]
   ```
   The script returns a JSON array of matching entries sorted by date. Each entry includes a `_path` field with the full filesystem path to the entry file.
4. For a quick overview, use the `summary` field from the list output. Only read full entry files (via `_path`) for entries that are flagged (blog-worthy, demo-worthy, reusable) or need deeper context.
5. Compose a **narrative recap** — not a raw dump. Structure it as:

```markdown
## Recap: <date-range> [for <project>]

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
