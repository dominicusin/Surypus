---
name: kspec-spec
description: Create a kspec specification from a feature description or Jira issue. Invoked via /kspec-spec, optionally with --jira <KEY>, a Jira URL, or a free-text feature title.
---
# kspec-spec — create a specification

You were invoked via `/kspec-spec`. **Do not ask "what would you like to spec?"** — execute the workflow below.

## Step 1 — Find the user's input (scan everywhere)

Look in this message body, prior turns, and any context entries for ANY of:

- A `--jira <KEY>` or `--jira=<KEY>` flag (comma-separated keys allowed, e.g. `--jira PROJ-123,PROJ-456`)
- A Jira URL: `*.atlassian.net/browse/<KEY>`, `*.atlassian.com/browse/<KEY>`, or `*.jira.com/browse/<KEY>` — the key is the trailing segment after `/browse/`
- A bare issue key matching `[A-Z][A-Z0-9_]+-\d+` (PROJ-123, ACME-456, etc.)
- Any free-text description (even meta phrasing like "create a spec for X" — treat as the feature title)

## Step 2 — If Jira input found, proceed (no clarifying question)

1. Extract the issue key(s).
2. Use any Atlassian MCP tool (`@atlassian`, `@jira`, or any tool whose name contains "atlassian"/"jira") to fetch each issue's summary, description, acceptance criteria, comments.
3. Strip the flag/URL/key from the input — the remainder is the **feature title**; use it verbatim even if it sounds meta. If nothing remains, derive a title from the first key (e.g. `jira-proj-123`).
4. If no Atlassian MCP is available, tell the user once to configure it (`kiro-cli mcp add --name atlassian`) or use `kspec spec --jira PROJ-123 "Feature"` from the terminal. Do not invent ticket content.

## Step 3 — If only a free-text feature description, write the spec

Use the description as the feature title and proceed. You may ask 1-2 targeted follow-ups about scope or non-functional behaviour, but propose defaults the user can confirm with a single word.

## Step 4 — Write files

Create `.kiro/specs/YYYY-MM-DD-<slug>/` with:
- `spec.md` — problem, requirements, constraints, design sketch, acceptance criteria, contract block. If from Jira, include `Source: <JIRA-KEY>` attribution and a link.
- `spec-lite.md` — under 500 words, compressed for post-compaction recovery.

Then write the folder path to `.kiro/.current` and refresh `.kiro/CONTEXT.md`.

## Step 5 — Suggest next step

Architecture: `kspec design` or `/agent swap kspec-design`. Tasks: `kspec tasks` or `/agent swap kspec-tasks`. Then `/kspec-build` for strict TDD.

## Examples (each is valid — execute, do not ask)

```
/kspec-spec --jira ACME-456 "create a spec from ticket ACME-456"
  → key=ACME-456, title="create a spec from ticket ACME-456" (meta title is valid)

/kspec-spec PROJ-123 build login feature
  → key=PROJ-123, title="build login feature"

/kspec-spec https://acme.atlassian.net/browse/SEC-42
  → key=SEC-42, title derived="jira-sec-42"

/kspec-spec --jira PROJ-123,PROJ-456 "auth + 2fa"
  → keys=[PROJ-123, PROJ-456], title="auth + 2fa", consolidated spec
```

## Last resort

Only if you genuinely cannot find ANY Jira reference OR ANY free-text feature description anywhere in context (truly empty invocation), respond with a single short line: `Send me a Jira key, URL, or feature description.` — do **not** offer a multi-option menu and do **not** repeat back the list of valid forms.
