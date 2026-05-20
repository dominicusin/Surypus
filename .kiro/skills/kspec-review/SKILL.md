---
name: kspec-review
description: Multi-CLI parallel code review (kiro-cli + Copilot/Claude/Gemini/Codex/Aider) with synthesis
---
# Review code with multiple AI reviewers

Use this skill when finishing a feature or before merging a PR. Runs every
configured reviewer CLI in parallel, then synthesizes findings.

## When to invoke
- "Review my changes"
- "Check this PR"
- "What did I miss?"

## Workflow
1. Read `.kiro/config.json` for configured reviewers (copilot, gemini,
   claude, codex, aider). Skip absent CLIs gracefully.
2. Gather context: spec, steering rules, git diff vs main.
3. Launch all configured reviewers in parallel with the same context.
4. Collect findings, deduplicate, classify by severity.
5. Output a consolidated report with consensus verdict.

## Compliance check
- Steering rules in `.kiro/steering/`
- Spec acceptance criteria in `.kiro/specs/<current>/spec.md`
- Test coverage threshold from `testing.md`

## Related
- Terminal: `kspec review` (or `--simple` for kiro-cli only)
- Direct agent: `/agent swap kspec-review`
- After review: `/kspec-build` to fix issues
