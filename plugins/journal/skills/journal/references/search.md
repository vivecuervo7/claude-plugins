# Search Mode

## Parsing

```
/journal search #blog-worthy          → tag search
/journal search my-api                → project search
/journal search 2026-03               → date prefix search
/journal search #architecture myproj  → combined filters
```

## Steps

1. Parse the query into filters:
   - Words starting with `#` → tag filters
   - Words matching `YYYY-MM` → convert to `--from YYYY-MM-01 --to YYYY-MM-{last day}`
   - Words matching `YYYY-MM-DD` → use as both `--from` and `--to`
   - Other words → project name filter
2. Glob for monthly index files: `$JOURNAL_ROOT/entries/*/*/index.json`
   - If a date filter narrows the months, only glob those.
3. Query entries using the bundled script. Pass all matching index paths (comma-separated) and filters:
   ```bash
   node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js list "path1/index.json,path2/index.json" [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--project name] [--tag name]
   ```
   The script returns a JSON array of matching entries sorted by date. For multiple tags, run once per tag and intersect results.
4. Output results as a table or list:

```markdown
## Search: <query>

| Date | Project | Summary | Tags |
|------|---------|---------|------|
| 2026-03-05 | my-api | Added rate limiting to API endpoints | feature, blog-worthy |

Found N entries. Use `/journal recap` for a narrative summary.
```

If few results (≤5), also show the `_path` values so the user can read full entries.
