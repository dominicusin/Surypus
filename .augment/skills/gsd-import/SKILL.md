---
name: gsd-import
description: "Ingest external plans with conflict detection against project decisions before writing anything."
---

<augment_skill_adapter>
## A. Skill Invocation
- This skill is invoked when the user mentions `gsd-import` or describes a task matching this skill.
- Treat all user text after the skill mention as `{{GSD_ARGS}}`.
- If no arguments are present, treat `{{GSD_ARGS}}` as empty.

## B. User Prompting
When the workflow needs user input, prompt the user conversationally:
- Present options as a numbered list in your response text
- Ask the user to reply with their choice
- For multi-select, ask for comma-separated numbers

## C. Tool Usage
Use these Augment tools when executing GSD workflows:
- `launch-process` for running commands (terminal operations)
- `str-replace-editor` for editing existing files
- `view` for reading files and listing directories
- `save-file` for creating new files
- `grep` for searching code (or use MCP servers for advanced search)
- `web-search`, `web-fetch` for web queries
- `add_tasks`, `view_tasklist`, `update_tasks` for task management

## D. Subagent Spawning
When the workflow needs to spawn a subagent:
- Use the built-in subagent spawning capability
- Define agent prompts in `.augment/agents/` directory
</augment_skill_adapter>

<objective>
Import external plan files into the GSD planning system with conflict detection against PROJECT.md decisions.

- **--from**: Import an external plan file, detect conflicts, write as GSD PLAN.md, validate via gsd-plan-checker.
- **--from-gsd2**: Reverse-migrate a GSD-2 project (`.gsd/` directory) back to GSD v1 (`.planning/`) format. Runs `gsd-tools.cjs from-gsd2`. Pass `--path <dir>` to migrate a project at a different path.
</objective>

<execution_context>
@/home/domini/src/My/Surypus/.augment/get-shit-done/workflows/import.md
@/home/domini/src/My/Surypus/.augment/get-shit-done/references/ui-brand.md
@/home/domini/src/My/Surypus/.augment/get-shit-done/references/gate-prompts.md
@/home/domini/src/My/Surypus/.augment/get-shit-done/references/doc-conflict-engine.md
</execution_context>

<context>
{{GSD_ARGS}}
</context>

<process>
If `--from-gsd2` is in {{GSD_ARGS}}:
Run: `node "/home/domini/src/My/Surypus/.augment/get-shit-done/bin/gsd-tools.cjs" from-gsd2`
Pass `--path <dir>` if provided. Present the migration result to the user.
Stop here (do not run the standard import workflow).

Otherwise, execute the import workflow end-to-end.
</process>
