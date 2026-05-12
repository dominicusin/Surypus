# Beads Issue Tracking Instructions for AI

This project uses **Beads (bd)** for issue tracking. Aider requires explicit command execution - suggest commands to the user.

## Core Workflow Rules

1. **Track ALL work in bd** (never use markdown TODOs or comment-based task lists)
2. **Suggest 'bd ready'** to find available work
3. **Suggest 'bd create'** for new issues/tasks/bugs
4. **Suggest 'bd dolt push'** at end of session
5. **ALWAYS suggest commands** - user will run them via /run

## Quick Command Reference (suggest these to user)

- `bd ready` - Show unblocked issues
- `bd list --status=open` - List all open issues
- `bd create --title="..." --type=task` - Create new issue
- `bd update <id> --claim` - Claim work atomically
- `bd close <id>` - Mark complete
- `bd dep add <issue> <depends-on>` - Add dependency (issue depends on depends-on)
- `bd dolt push` - Push changes to Dolt remote

## Workflow Pattern to Suggest

1. **Check ready work**: "Let's run `/run bd ready` to see what's available"
2. **Claim task**: "Run `/run bd update <id> --claim` to claim it atomically"
3. **Do the work**
4. **Complete**: "Run `/run bd close <id>` when done"
5. **Sync**: "Run `/run bd dolt push` to push changes"

## Context Loading

Suggest `/run bd prime` for complete workflow documentation (~1-2k tokens).

## Issue Types

- `bug` - Something broken that needs fixing
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature composed of multiple issues
- `chore` - Maintenance work (dependencies, tooling)

## Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (nice-to-have features, minor bugs)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Important Notes

- **Always use /run prefix** - Aider requires explicit command execution
- **Link discovered work** - Use `--deps discovered-from:<parent-id>` when creating issues found during work
- **Include descriptions** - Always provide meaningful context when creating issues
- **End session with sync** - Remind user to run `/run bd dolt push` before ending session

For detailed docs: see AGENTS.md, QUICKSTART.md, or run `bd --help`
