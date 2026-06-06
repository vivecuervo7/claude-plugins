# wrought

Drive your live browser session from Claude.

`wrought` is a thin wrapper around `playwright-cli` that lets Claude attach to a long-running browser session, invoke replayable snippets, and author new ones on demand. Common interactions are saved as small `.ts` files Claude can replay later without re-investigating the DOM, and the same tooling will generate real Playwright specs from a recorded session (future work).

The plugin owns the *browser as a long-lived daemon*: you attach (or launch) once, and Claude, you, and any future tooling all act on the same window via the named `wrought` playwright-cli session.

## Status

Step 2 of a larger design. Today the plugin ships:

- A `browser-session` skill — Claude knows how to ensure the `wrought` session exists, invoke a registered snippet, and delegate authoring.
- A session helper — probes `localhost:9222` for an existing CDP-enabled browser (attach `--cdp`), falls back to launching managed Chrome with a dedicated persistent profile (`open --persistent --profile=...`).
- A snippet registry — list, show, reindex, invoke. Invocation shells out to `playwright-cli -s=wrought run-code "..."` with precondition checks prepended and args inlined.
- A `snippet-author` agent — drives the `wrought` session via playwright-cli, captures the working path into a `.ts` file in `scratch/`, and returns a small structured summary to the caller. DOM noise stays in the agent's context window.

Future steps: scratch → staged → library auto-promotion on reuse, a `snippet-repair` agent for self-healing under DOM drift, a session recorder, and `/spec from-session` for generating frozen Playwright specs.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install wrought@vive-claude
```

First use bootstraps a data root under `~/.claude/.vive-claude/wrought/`. The bootstrap is idempotent.

## Requirements

- **playwright-cli** — `brew install playwright-cli`. Wrought is a wrapper, not a replacement.
- **macOS** for now (the managed-launch fallback targets `/Applications/Google Chrome.app`; the CDP-attach path works against any Chromium-family browser).
- **Node.js** (any recent version — tested on 24).

## Attaching to your existing browser

For "take-the-reins" mode where Claude acts on the browser session you've been using, launch your everyday Chromium-family browser (Chrome, Arc, Brave, Edge) with `--remote-debugging-port=9222`:

```bash
# Example shell alias for everyday Chrome:
alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222 --user-data-dir=$HOME/.cache/chrome-cdp'
```

When `wrought-session.sh` runs and detects the CDP port, it'll attach. You stay in control; Claude takes the wheel when you ask.

If you'd rather Claude drive a separate browser (real cookies stay yours), skip the CDP setup and `wrought-session.sh` will launch a managed Chrome with its own persistent profile.

## Storage

Runtime data lives at `~/.claude/.vive-claude/wrought/`:

```
~/.claude/.vive-claude/wrought/
├── INDEX.md              # auto-generated retrieval index (name — description per line)
├── stats.json            # per-snippet { tier, useCount, lastUsed, createdAt }
├── scratch/              # 7-day TTL (cleanup wired up in a later step)
├── staged/               # promoted on second use
├── library/              # promoted on third use; never auto-deleted
├── broken/               # quarantined after failed repair
├── sessions/             # recorder transcripts (future)
└── chromium-profile/     # dedicated profile for managed-launch fallback
```

Nothing here belongs in a git repo. Snippets may contain references to user-specific selectors, URLs, or paths captured during authoring — keep them off-disk-of-record.

## License

MIT
