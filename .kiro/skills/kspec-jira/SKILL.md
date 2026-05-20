---
name: kspec-jira
description: Sync kspec spec/tasks to Jira (pull issues, push specs, create sub-tasks, link spec ↔ tickets)
---
# Sync kspec to Jira

Use this skill for any Jira operation: pulling issues into a spec, pushing
spec content back to Jira, creating sub-tasks, or pulling latest ticket
updates. Requires the Atlassian MCP server to be configured.

## When to invoke
- "Create a Jira ticket for this spec"
- "Sync my tasks to Jira sub-tasks"
- "Update the Jira issue with progress"
- "Pull latest from Jira" / "Sync from Jira"
- CLI-style flags also work in chat:
  - `/kspec-jira --update PROJ-123` — update specific issue with current spec
  - `/kspec-jira --create` — force-create a new issue (don't update existing)
  - `/kspec-jira --project SECOPS` — create in a specific project (overrides default)
  - `/kspec-jira --tags "driver:engineering,type:spike"` — attach labels (see Tags below)
  - `/kspec-jira subtasks PROJ-123` — create sub-tasks under PROJ-123
  - `/kspec-jira pull` — pull latest from linked issues into a change report

## Prerequisites
- Atlassian MCP configured (`kiro-cli mcp add --name atlassian`)
- Default Jira project in `.kiro/config.json` (set during `kspec init`)

## Step 1 — Detect intent + Jira input
Parse the user's message for:

**Action keywords** (decides which mode):
- "create", "push", "sync to" → SYNC TO JIRA mode
- "pull", "sync from", "fetch updates" → PULL UPDATES mode
- "subtasks", "sub-tasks", "subtask" → CREATE SUBTASKS mode

**Flags** (CLI parity):
- `--update <KEY>` or `--update=<KEY>` → update existing issue with current spec
- `--create` → force-create new issue (skip existing-link check)
- `--project <KEY>` or `--project=<KEY>` → override default project
- `--jira <KEY>` or `--jira=<KEY>` → operate on these specific issue(s) (comma-separated allowed)
- `--tags "<csv>"` or `--labels "<csv>"` → attach labels to created/updated issues (see Tags below)

**Jira references** (used for pull / subtasks):
- URL: `https://*.atlassian.net/browse/<KEY>`, `*.atlassian.com/browse/<KEY>`, `*.jira.com/browse/<KEY>`
- Bare key: `[A-Z][A-Z0-9_]+-\d+` (e.g. `PROJ-123`, multiple comma-separated allowed)

If no Atlassian MCP is available, tell the user to configure it (`kiro-cli mcp add --name atlassian`) or use the matching CLI command (`kspec sync-jira`, `kspec jira-pull`, `kspec jira-subtasks`).

## Tags / Labels

Attach arbitrary labels to created or updated Jira issues. Useful for R&D
categorisation, team ownership, feature type, quarter, etc.

**Syntax** (both forms equivalent — `--labels` is Jira's actual term):
```
/kspec-jira --create --tags "driver:engineering,type:spike,team:platform"
/kspec-jira --update PROJ-123 --labels "q1-2026,priority:p2"
```

**Parsing rules**:
- Split on comma; trim whitespace around each value.
- Each tag is a free-form string. Colons, dashes, dots, slashes are allowed (`driver:engineering`, `q1-2026`, `area/auth`).
- Drop empty values.
- **No spaces inside a label** — Jira rejects them. If the user passes `type: spike` (with space), normalise to `type:spike` and warn.

**Behaviour**:
- **CREATE / SYNC**: merge `--tags` with the default kspec labels (`kspec`, `technical-specification`) AND any configured `config.jira.defaultTags` from `.kiro/config.json`. De-duplicate.
- **UPDATE**: fetch the issue's current labels first, then UNION with `--tags`. Never clobber user-added labels.
- **SUBTASKS**: each sub-task inherits the parent issue's labels by default, plus any `--tags` passed.

**Config default** (org-level): set in `.kiro/config.json`:
```json
{ "jira": { "defaultTags": ["rd", "kspec-managed"] } }
```
These apply to every issue kspec creates. `--tags` adds to (not replaces) these defaults.

## Step 2 — Execute the mode

### SYNC TO JIRA
1. Read current spec from `.kiro/.current` and `spec.md`.
2. Read `<spec>/jira-links.json` for existing links.
3. Build the label set: `config.jira.defaultTags` ∪ `["kspec", "technical-specification"]` ∪ `--tags` (de-duplicated).
4. If `--create` or no existing link: post a new "Technical Specification" issue (use `--project` if given, else default from config) with the label set from step 3.
5. If `--update <KEY>` or an existing link is found: patch that issue's description with current spec content. UNION the issue's existing labels with the label set from step 3 (never clobber user labels). Add a comment summarising the update.
6. Save the link(s) back to `jira-links.json` and refresh `.kiro/CONTEXT.md`.

### PULL UPDATES
1. Use issue keys from `jira-links.json` (or the explicit keys passed in).
2. Fetch latest state of each via the Atlassian MCP.
3. Diff against current `spec.md` and generate a **CHANGE REPORT** showing new/modified acceptance criteria, description changes, new comments, status changes.
4. **NEVER auto-update spec.md** — show the report and wait for user confirmation.
5. On approval, update `spec.md` and regenerate `spec-lite.md`.

### CREATE SUBTASKS
1. Read `tasks.md` from current spec.
2. Determine parent issue: use the key passed in (if any), else the first entry in `jira-links.json`.
3. Fetch the parent's labels — sub-tasks inherit these by default.
4. Build the label set per task: parent's labels ∪ `config.jira.defaultTags` ∪ `--tags` (de-duplicated).
5. Create one Jira sub-task per task, with the label set from step 4. Include task details and acceptance criteria.
6. Save the new sub-task keys to `jira-links.json`.

## Step 3 — Always
- Include "Source: JIRA-XXX" attribution in spec.md for pulled content
- Update `.kiro/CONTEXT.md` with the latest Jira link summary
- Report what was created/updated to the user

## Related
- Terminal equivalents (same behaviour):
  - `kspec sync-jira` / `--create` / `--update KEY` / `--project KEY`
  - `kspec jira-pull`
  - `kspec jira-subtasks` / `kspec jira-subtasks PROJ-123`
- Direct agent: `/agent swap kspec-jira`
- Pull a Jira ticket INTO a fresh spec instead: `/kspec-spec --jira PROJ-123 "Feature"`
