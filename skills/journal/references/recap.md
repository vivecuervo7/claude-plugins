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
3. Read each relevant index and filter entries by date range and optional project.
4. Read the actual entry files for full content.
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
