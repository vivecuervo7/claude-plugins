# Search Mode

## Parsing

```
/journal search #blog-worthy          → tag search
/journal search my-api                → project search
/journal search 2026-03               → date prefix search
/journal search #architecture myproj  → combined filters
/journal search "validation pattern"  → text search (quoted or unmatched words)
/journal search Redux walkthrough     → text search (no structured match)
```

Classify the query:
- Words starting with `#` → tag filters
- Words matching `YYYY-MM` → date prefix, convert to `--from YYYY-MM-01 --to YYYY-MM-{last day}`
- Words matching `YYYY-MM-DD` → use as both `--from` and `--to`
- A single word that matches a known project name → project filter
- **Everything else** → full-text search terms

Structured filters (tags, dates, projects) and text search can be combined. If a query has ONLY unstructured words (no `#`, no dates, doesn't match a project), treat the entire query as a text search.

## Steps

### Structured search (tags, dates, projects)

1. Glob for monthly index files: `$JOURNAL_ROOT/entries/*/*/index.json`
   - If a date filter narrows the months, only glob those.
2. Query entries using the bundled script. Pass all matching index paths (comma-separated) and filters:
   ```bash
   node ${CLAUDE_SKILL_DIR}/scripts/journal-index.js list "path1/index.json,path2/index.json" [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--project name] [--tag name]
   ```
   The script returns a JSON array of matching entries sorted by date. For multiple tags, run once per tag and intersect results.

### Full-text search (body content)

When the query includes text search terms, grep entry files for matches:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/journal-search-text.sh "$JOURNAL_ROOT" "<search terms>"
```

The script returns matching file paths with context lines. If combined with structured filters, first get the structured results, then grep only those entry files for the text terms.

### Output

```markdown
## Search: <query>

| Date | Project | Summary | Tags |
|------|---------|---------|------|
| 2026-03-05 | my-api | Added rate limiting to API endpoints | feature, blog-worthy |

Found N entries. Use `/journal recap` for a narrative summary.
```

For text search results, include a brief excerpt showing the matching context.

If few results (≤5), also show the `_path` values so the user can read full entries.
