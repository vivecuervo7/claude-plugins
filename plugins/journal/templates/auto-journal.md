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
