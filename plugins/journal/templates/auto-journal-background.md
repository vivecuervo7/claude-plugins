# Auto-Journal

After completing a task that involves decisions, non-obvious solutions,
architectural choices, multi-step implementation, or learning worth capturing —
journal it. Skip routine config changes, simple file additions, and mechanical
tasks unless they contain an insight worth preserving.

First check whether background journaling is ready:

    bash {{PLUGIN_ROOT}}/scripts/journal-ready.sh

Read the `BACKGROUND_READY` line from its output:

- `BACKGROUND_READY=true` → spawn the append agent in the background:
  Agent(subagent_type="journal:journal-append",
    prompt="<what was done>", run_in_background=true)
- otherwise → spawn it in the foreground as normal:
  Agent(subagent_type="journal:journal-append",
    prompt="<what was done>")
  and add a short parenthetical to your relay noting background was skipped this
  time (e.g. "(background not ready — journaled inline)").

Either way the entry gets written; readiness only decides blocking vs
non-blocking.

When the journal-append agent completes, **always relay its result to the user**
in a brief message. This surfaces the confirmation and any media hints (e.g.
"Capture while fresh: ...") so the user can act on them without checking tasks.
