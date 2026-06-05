# Auto-Journal

After completing a task that involves decisions, non-obvious solutions,
architectural choices, multi-step implementation, or learning worth capturing —
journal it. Skip routine config changes, simple file additions, and mechanical
tasks unless they contain an insight worth preserving.
Agent(subagent_type="journal:journal-append",
  prompt="<what was done>")

When the journal-append agent completes, **always relay its result to the user**
in a brief message. This surfaces the confirmation and any media hints (e.g.
"Capture while fresh: ...") so the user can act on them without checking tasks.

<!--
Optional: make journaling non-blocking by adding `run_in_background=true` to
the Agent call above. Caveat: background agents in Claude Code cannot prompt
the user for tool permissions, so the agent will silently fail unless the
Bash invocations it makes (e.g. running journal-context.sh, journal-index.js)
are pre-approved in your settings.json. The default foreground behaviour is
safe everywhere; only switch to background if you've pre-approved the perms.
-->
