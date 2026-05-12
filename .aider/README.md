# Aider + Beads Integration

This project uses [Beads (bd)](https://github.com/steveyegge/beads) for issue tracking.

## How This Works with Aider

**Important**: Aider requires you to explicitly run commands using the `/run` command.
The AI will **suggest** bd commands, but you must confirm them.

## Quick Start

1. Check for available work:
   ```bash
   /run bd ready
   ```

2. Create new issues:
   ```bash
   /run bd create "Issue title" --description="Details" -t bug|feature|task -p 1
   ```

3. Claim work:
   ```bash
   /run bd update bd-42 --claim
   ```

4. Complete work:
   ```bash
   /run bd close bd-42 --reason "Done"
   ```

5. Sync at end of session:
   ```bash
   /run bd dolt push
   ```

## Configuration

The `.aider.conf.yml` file contains instructions for the AI about bd workflow.
The AI will read these instructions and suggest appropriate bd commands.

## Workflow

Ask the AI questions like:
- "What issues are ready to work on?"
- "Create an issue for this bug I found"
- "Show me the details of bd-42"
- "Mark bd-42 as complete"

The AI will suggest the appropriate `bd` command, which you run via `/run`.

## Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance work

## Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## More Information

- Run `bd --help` for full command reference
- See `AGENTS.md` for detailed AI integration docs
- See `QUICKSTART.md` for human-oriented guide
