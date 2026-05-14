---
name: gsd-ns-manage
description: "config workspace | workstreams thread update ship inbox"
---

<augment_skill_adapter>
## A. Skill Invocation
- This skill is invoked when the user mentions `gsd-ns-manage` or describes a task matching this skill.
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

Route to the appropriate management skill based on the user's intent.
`gsd-config` (settings + advanced + integrations + profile) and `gsd-workspace`
(new + list + remove) are post-#2790 consolidated entries.

| User wants | Invoke |
|---|---|
| Configure GSD settings (basic / advanced / integrations / profile) | gsd-config |
| Manage workspaces (create / list / remove) | gsd-workspace |
| Manage parallel workstreams | gsd-workstreams |
| Continue work in a fresh context thread | gsd-thread |
| Pause current work | gsd-pause-work |
| Resume paused work | gsd-resume-work |
| Update the GSD installation | gsd-update |
| Ship completed work | gsd-ship |
| Process inbox items | gsd-inbox |
| Create a clean PR branch | gsd-pr-branch |
| Undo the last GSD action | gsd-undo |

Invoke the matched skill directly using the Skill tool.
