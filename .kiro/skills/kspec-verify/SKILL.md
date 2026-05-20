---
name: kspec-verify
description: Verify a spec, design, tasks, or implementation against acceptance criteria
---
# Verify kspec artifacts

Use this skill at any phase boundary (spec → design → tasks → implementation)
to confirm the artifact is complete, consistent, and meets acceptance criteria.

## When to invoke
- "Is the spec ready for design?"
- "Did I cover all the tasks?"
- "Is the implementation done?"

## Workflow
1. Read `.kiro/.current` to get the current spec folder.
2. Identify the artifact to verify (spec.md / design.md / tasks.md / code).
3. Check each acceptance criterion is addressed.
4. Flag gaps, ambiguities, or missing edge cases.
5. Output a clear pass/fail verdict with specific gap list.

## Related
- Terminal: `kspec verify` (or `verify-spec`, `verify-design`, `verify-tasks`)
- Direct agent: `/agent swap kspec-verify`
