# Phase 166: Real Login with DB Auth — Context

**Gathered:** 2026-05-26
**Status:** Ready for planning
**Mode:** Infrastructure phase — implementation already complete

<domain>
## Phase Boundary

Replace stub login with real PostgreSQL authentication using crypt() password verification.

- Fix `authenticateUser` to query `users` table instead of non-existent `usr` table
- Use `crypt($2, password_hash)` for bcrypt password comparison
- Return proper QuerySuccess responses for valid/invalid credentials
- Ensure stack build and stack test pass

</domain>

<decisions>
## Implementation Decisions

### Database Auth
- Query the `users` table for authentication
- Use PostgreSQL's `crypt()` function for bcrypt password verification
- Return `QuerySuccess (Just User)` on valid credentials
- Return `QuerySuccess Nothing` on invalid credentials
- The `handleLogin` in API/Server.hs is already properly wired

</decisions>

<code_context>
## Existing Code Insights

### Files Modified
- `surypus-api/src/Surypus/DAL/Mutations.hs` — authenticateUser SQL fixed
- `surypus-api/src/Surypus/API/Server.hs` — handleLogin (already correct, verified)

</code_context>

<specifics>
## Specific Ideas

No specific additional requirements — phase implemented and verified.

</specifics>

<deferred>
## Deferred Ideas

None

</deferred>

---

*Phase: 166-real-login-with-db-auth*
*Context gathered: 2026-05-26*
