---
name: gsd-undo
description: "Safe git revert. Roll back phase or plan commits using the phase manifest with dependency checks."
---


<objective>
Safe git revert — roll back GSD phase or plan commits using the phase manifest, with dependency checks and a confirmation gate before execution.

Three modes:
- **--last N**: Show recent GSD commits for interactive selection
- **--phase NN**: Revert all commits for a phase (manifest + git log fallback)
- **--plan NN-MM**: Revert all commits for a specific plan
</objective>

<execution_context>
@/home/domini/src/My/Surypus/.codebuddy/get-shit-done/workflows/undo.md
@/home/domini/src/My/Surypus/.codebuddy/get-shit-done/references/ui-brand.md
@/home/domini/src/My/Surypus/.codebuddy/get-shit-done/references/gate-prompts.md
</execution_context>

<context>
{{GSD_ARGS}}
</context>

<process>
Execute end-to-end.
</process>
