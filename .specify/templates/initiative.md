# Specification template (Spec Kit)

Copy this file when starting a new initiative. Keep it short and factual.

## Initiative: <name>

### Goal
<one paragraph, measurable outcome>

### Source of truth
- DSL entity / aggregate: `<Entity>`
- Command handlers: `sql/aggregate/V0XX__<entity>_aggregate.sql`
- Read model: `projection_<entity>`

### Acceptance criteria
- [ ] `surypus-codegen build` regenerates Schema.hs/Types.hs/SQL/QML
- [ ] `surypus-codegen check` passes (no working-tree drift)
- [ ] Generated `sql/migrations/V001__generated_orm.sql` loads on Postgres 18.4
- [ ] Generated QML passes `qmllint` (0 errors)
- [ ] Event-sourced path appends events and advances the projection
- [ ] CI gate green on a non-`main` branch (breaking-change check)

### Verification evidence
<real tool output: psql load result, qmllint count, event_store row count>
