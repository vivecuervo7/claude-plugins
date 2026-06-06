---
name: browser-session
description: "Drive a long-lived browser session through playwright-cli, addressing it as the named 'wrought' session. Use when the user asks Claude to do something in the browser (fill a form, paste a gif into a PR description, navigate a multi-step UI) and that action might be replayable. Always prefer invoking an existing snippet over driving the UI fresh."
allowed-tools: Read, Skill, Bash(bash **/wrought/*/scripts/*), Bash(node **/wrought/*/scripts/*), Bash(playwright-cli:*), Bash(curl -sf -m * http://localhost:9222/json/version*)
---

# browser-session

The always-loaded knowledge surface for driving a real browser from Claude. Wrought is a thin wrapper around `playwright-cli`: that skill owns the action vocabulary, wrought owns the session lifecycle, the snippet registry, and the spec-generation pipeline. This skill covers *attaching* and *invoking known snippets*. Authoring new snippets is delegated to the `wrought:snippet-author` agent (noise quarantine).

## When this skill applies

The user asked you to do something *in a browser* — paste a GIF into a PR description, navigate a multi-step UI, fill a form, verify a behaviour by clicking through. Two paths:

1. **A registered snippet covers the request** (possibly with arg overrides). Invoke it. The registry handles precondition checks, stats, and history. Before delegating to the author agent, **read each candidate snippet's `meta.args` and description** — many snippets accept args that cover variations of their default behaviour (e.g. `hn-story-title` with `{rank: 2}` for the 2nd story). If you can fulfil the request with an arg override, do that.

2. **No snippet covers it, even with args.** Delegate to the `wrought:snippet-author` agent. It drives the browser, synthesises a `.ts` snippet, writes it to `scratch/`, records the drive as the first use, and returns a structured summary that *includes the observed result*. **You do NOT re-invoke the new snippet** — the agent's drive was the first execution. Just report the result the agent returned.

If the user is asking about something that *isn't* in a browser, you're in the wrong skill.

## How to drive the system

All commands assume the runtime is bootstrapped. Run the bootstrap once at session start (idempotent and fast on subsequent runs):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-bootstrap.sh
```

The bootstrap emits `WROUGHT_ROOT=…`, `WROUGHT_PROFILE=…`, `WROUGHT_SESSION=wrought`, `PLAYWRIGHT_CLI=…` as `KEY=VALUE` lines. Capture them if you need to reference paths.

### Ensure the wrought playwright-cli session exists

Before any browser work, the named `wrought` session must be active. `wrought-session.sh` handles probe → attach-cdp → managed-launch fallback:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-session.sh --probe-only
```

- Exit 0 → session is established (already-running, CDP-attached to your real Chrome, or a managed Chrome that's still alive).
- Exit 1 → no session and no CDP browser to attach to. **Ask the user before establishing one**, because the side effect is visible:

  > No `wrought` session is active and nothing is listening on localhost:9222. I can launch a managed Chrome with a dedicated profile at `~/.claude/.vive-claude/wrought/chromium-profile/`. This is a separate browser from your everyday Chrome — fresh cookies, fresh history. OK to proceed?

  On approval, drop the `--probe-only` flag:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-session.sh
  ```

  If the user *was* already browsing in a CDP-enabled Chrome (Arc with `--remote-debugging-port=9222`, or any Chromium-family browser launched with that flag), the script will detect it and attach. Real cookies, real auth, real tabs — surface that to the user so they know what's about to happen.

### Find a snippet

```bash
cat $WROUGHT_ROOT/INDEX.md
```

The index is `library` → `staged` → `scratch` → `broken`, with each tier's snippets listed as `` `name` — description ``. Match on description; ignore `broken/` (those need repair before invocation).

For richer detail than the index line:

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-registry.mjs show <name>
```

Returns metadata (tier, path, stats) and the full source. The source is the authoritative description of what args it takes and what it does.

### Invoke a snippet

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-registry.mjs invoke <name> '<json-args>'
```

The registry dynamic-imports the snippet, extracts the `run` body, prepends precondition checks, inlines `args`, and shells out to `playwright-cli -s=wrought run-code "..."`. Output is one line of JSON:

- `{"ok":true,"tier":"library","useCount":4,"output":"..."}` — success. Stats bumped, history appended.
- `{"ok":false,"stage":"precondition","error":"precondition: url expected /github\\.com\\.+\\/pull\\/\\d+/ but on https://www.google.com"}` — preconditions failed. Don't retry blindly. Surface the reason and ask the user how to proceed (e.g. navigate first, then retry).
- `{"ok":false,"stage":"run","error":"..."}` — the snippet itself threw. In a future step this will trigger a `snippet-repair` agent. For now, report the error and tell the user the snippet may have drifted under DOM changes.

### Delegate authoring when no snippet matches

If the index has nothing relevant, **spawn the `wrought:snippet-author` agent** rather than doing the driving yourself. The agent quarantines DOM exploration in its own context window so this conversation stays narrow.

Before delegating, confirm the wrought session is alive (see "Ensure the wrought session exists" above). Then:

```
Agent(subagent_type="wrought:snippet-author",
  prompt="Goal: <natural language goal>
Suggested name: <optional kebab-case name>
Args: <optional comma-separated arg names and any user-supplied values>
Context: <optional — current URL, ticket ref, prerequisite state>")
```

The agent returns exactly one of:

- `Authored: <name> → scratch/<name>.ts` followed by `Description:`, `Args:`, `Preconditions:`, `Result:`, and optionally `Confirm:`. **Do NOT re-invoke** — the agent's drive was the first execution. Steps:
  1. Report the `Result:` value to the user as the answer to their request.
  2. If a `Confirm:` line is present, the agent is uncertain about whether the outcome matches user intent (often relevant for write/submit actions where the return value is ambiguous). Ask the user the question. If they confirm the outcome is correct, you're done. If they say it's wrong, surface the issue and offer to delete the snippet — it shouldn't enter the library on a bad first impression:
     ```bash
     node ${CLAUDE_PLUGIN_ROOT}/scripts/wrought-registry.mjs delete <name>
     ```
     This removes the `.ts`, the history, and the stats entry in one atomic step.
- `Duplicate: <existing-name>` — the agent found an existing snippet that covers the goal. Invoke that one instead.
- `no-session: ...` — the session check failed in the agent's environment. Re-run `wrought-session.sh`.
- `cannot-author: <reason>` — the agent couldn't reach the goal. Surface the reason to the user; consider whether you misunderstood the goal, or whether the page state is something the user needs to set up first.

### What you must NOT do in this skill

- **Don't drive the browser yourself for authoring.** Delegate to the agent. The DOM noise belongs in its context, not this one.
- **Don't repair failing snippets inline.** A `stage: "run"` failure from invoke means the snippet has drifted. Tell the user the snippet may need re-authoring (future: a `snippet-repair` agent). For now: report the error, delete the broken `scratch/` snippet if appropriate, delegate fresh authoring.
- **Don't write to `library/` or `staged/` directly.** Those tiers are managed by the (future) promotion machinery. The snippet-author agent always writes to `scratch/`.
- **Don't tear down the wrought session.** `playwright-cli -s=wrought close` / `detach` is a lifecycle action the user controls — never run it yourself.

## Storage layout reference

```
$WROUGHT_ROOT/                        # ~/.claude/.vive-claude/wrought/
├── INDEX.md                          # auto-generated retrieval surface
├── stats.json                        # per-snippet metadata
├── scratch/  staged/  library/       # snippet tiers
├── broken/                           # quarantined; needs repair
├── sessions/                         # recorder transcripts (future)
└── chromium-profile/                 # dedicated profile for managed launch
```

See `references/snippet-anatomy.md` for the snippet file format and `references/attach.md` for the session-mode state machine in detail.
