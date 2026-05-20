---
name: kspec-build
description: Execute kspec tasks with strict TDD (red → green → refactor → full suite)
---
# Build a kspec spec with strict TDD

Use this skill to implement an existing kspec spec one task at a time, with
mandatory red-green-refactor discipline.

## When to invoke
- "Build the next task"
- "Implement the spec"
- "Pick up where we left off"

## Strict TDD (do NOT skip steps)
1. **RED** — Write a failing test that captures the expected behavior.
2. **VERIFY RED** — Run the test. Confirm it FAILS. Log the failure output.
   If it passes, the test is wrong — investigate. Do NOT proceed until you
   have a confirmed failing test.
3. **GREEN** — Write the MINIMUM code to make the failing test pass.
4. **VERIFY GREEN** — Run the test. Confirm it passes.
5. **REFACTOR** — Clean up. Run tests again to confirm no regression.
6. **FULL SUITE** — Run ALL tests to ensure nothing else broke.

Each red-green-refactor cycle = one commit with descriptive message.

## Related
- Terminal: `kspec build` (or `kspec build --chunk N`, `--all`, `--no-tdd`)
- Direct agent: `/agent swap kspec-build`
- After build: `/kspec-verify` or `/kspec-review`
