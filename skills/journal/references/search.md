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
   - Words matching `YYYY-MM` or `YYYY-MM-DD` → date filters
   - Other words → project name filter
2. Glob for monthly index files: `$JOURNAL_ROOT/entries/*/*/index.json`
   - If a date filter narrows the months, only read those.
3. Read indexes and filter entries matching ALL specified filters.
4. Output results as a table or list:

```markdown
## Search: <query>

| Date | Project | Summary | Tags |
|------|---------|---------|------|
| 2026-03-05 | my-api | Added rate limiting to API endpoints | feature, blog-worthy |

Found N entries. Use `/journal recap` for a narrative summary.
```

If few results (≤5), also show the file paths so the user can read full entries.
