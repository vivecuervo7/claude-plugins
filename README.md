# claude-plugins

Claude Code plugins for developer productivity. A small collection of focused tools — some run automatically in the background, others are slash commands you invoke when you need them. Polished enough to share with colleagues.

## Install

Add the marketplace:

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
```

Then install individual plugins:

```bash
claude plugin install journal@vive-claude
claude plugin install media@vive-claude
claude plugin install wrought@vive-claude
```

## Plugins

| Plugin | Description |
|--------|-------------|
| [journal](plugins/journal/) | Automatic developer journaling — captures decisions, architecture, and learnings as you work |
| [media](plugins/media/) | Media utilities — opinionated commands for working with screen recordings and video |
| [wrought](plugins/wrought/) | Drive your live browser session from Claude — attach over CDP, invoke replayable snippets |

## License

MIT
