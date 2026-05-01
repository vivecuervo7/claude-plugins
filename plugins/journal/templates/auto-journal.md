# Auto-Journal

After completing a task that involves decisions, non-obvious solutions,
architectural choices, multi-step implementation, or learning worth capturing —
journal it. Skip routine config changes, simple file additions, and mechanical
tasks unless they contain an insight worth preserving.
Agent(subagent_type="journal:journal-worker",
  prompt="<what was done>")

When the journal-worker completes, **always relay its result to the user** in a
brief message. This surfaces the confirmation and any media hints (e.g.
"Capture while fresh: ...") so the user can act on them without checking tasks.
