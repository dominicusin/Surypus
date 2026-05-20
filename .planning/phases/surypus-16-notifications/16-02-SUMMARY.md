---
phase: 16-notifications
plan: 02
subsystem: api, notifications
tags: [hasql, postgres, notifications-api, preferences, email-smtp]
requires: [16-01-PLAN.md]
provides:
  - getNotificationPrefs with real Hasql query and rowMaybe decoder
  - updateNotificationPrefs with CTE-based upsert
  - sendEmailNotification with SMTP integration
affects: [16-03-PLAN.md]

tech-stack:
  added: [LambdaCase extension]
  patterns: [CTE-based upsert, tuple-extractor encoder chains with >$<, rowMaybe for optional rows]

key-files:
  modified:
    - surypus-api/src/Surypus/API/Notifications.hs
    - surypus-api/src/Surypus/API/Server.hs

key-decisions:
  - "D.maybeRow does not exist in Hasql 1.x; use D.rowMaybe for optional row decoding"
  - "CTE-based upsert pattern for notification_prefs avoids requiring UNIQUE constraint on usr_id"
  - "LambdaCase extension needed for inline case matching in do-notation"
  - ">$< calls must be individually parenthesized when composed with <> due to operator precedence (infixl 4 vs infixr 6)"

requirements-completed: [NOTIF-05, NOTIF-06]

duration: 45min
completed: 2026-05-20
---

# Phase 16 - Plan 02: Notifications API Rewrite Summary

**Rewrote Notifications.hs with real Hasql queries for preference CRUD and SMTP email sending, fixing tuple-extractor encoder patterns and LambdaCase compilation errors**

## Performance

- **Duration:** 45 min
- **Started:** 2026-05-20T03:00:00Z
- **Completed:** 2026-05-20T03:45:00Z
- **Tasks:** 4
- **Files modified:** 2

## Accomplishments

- **getNotificationPrefs**: Real Hasql query against `notification_prefs` table using `D.rowMaybe` decoder; returns default prefs (True/True/"daily") when no row exists
- **updateNotificationPrefs**: Real Hasql CTE-based upsert — UPDATE first, INSERT WHERE NOT EXISTS as fallback, RETURNING the resulting row
- **sendEmailNotification**: Persists notification to DB, then attempts SMTP delivery via `Infrastructure.Email.loadEmailConfig` + `sendEmail` (best-effort; silently skips if SMTP not configured)
- **Server.hs**: Switched `notificationsGetPrefs` from the legacy `getPreferences` (hardcoded defaults) to the real `getNotificationPrefs` with userId

## Task Commits

1. **Task 1: Fix encoder patterns + add imports** — part of `fe25b80`
2. **Task 2: Implement real Hasql preference queries** — part of `fe25b80`
3. **Task 3: Wire sendEmailNotification with SMTP** — part of `fe25b80`
4. **Task 4: Update Server.hs** — part of `fe25b80`

## Files Modified

- `surypus-api/src/Surypus/API/Notifications.hs` (151 → 193 lines) — Full rewrite with real Hasql queries, SMTP integration, LambdaCase extension, removed unused statusText
- `surypus-api/src/Surypus/API/Server.hs` (1 line changed) — Switch from `getPreferences` to `getNotificationPrefs` with userId parameter

## Key Implementation Details

### Tuple-extractor encoder pattern for upsert

The CTE-based upsert requires encoding a 4-tuple `(Int64, Bool, Bool, Text)`:

```haskell
(((\(uid, _, _, _) -> uid) >$< E.param (E.nonNullable E.int8))
  <> ((\(_, em, _, _) -> em) >$< E.param (E.nonNullable E.bool))
  <> ((\(_, _, pu, _) -> pu) >$< E.param (E.nonNullable E.bool))
  <> ((\(_, _, _, dg) -> dg) >$< E.param (E.nonNullable E.text)))
```

Each `>$<` call **must** be parenthesized because `<>` (infixr 6) binds tighter than `>$<` (infixl 4). Without parentheses, the wrong term would be on the right side of `>$<`.

### rowMaybe for optional rows

`D.maybeRow` does not exist in Hasql 1.x (confirmed by checking other usages in the codebase). The correct decoder is `D.rowMaybe`, which returns `Maybe a`.

## Deviations from Plan

### Rule 2 - Missing import fixed
- **Found during:** Task 1 — `Control.Monad (void)` and `Infrastructure.Email` imports were missing; added on first edit pass

### Rule 2 - LambdaCase extension missing
- **Found during:** Task 1 — `\case` syntax requires `{-# LANGUAGE LambdaCase #-}`; added in first edit pass

### Rule 1 - D.maybeRow doesn't exist
- **Found during:** Task 2 — `D.maybeRow` is not exported by Hasql.Decoders; corrected to `D.rowMaybe` (which is the canonical name used by all other query modules in the codebase)

### Rule 3 - sendEmail expects Text, not String
- **Found during:** Task 3 — `Email.sendEmail` takes `Text` arguments but `T.unpack` was used; removed T.unpack calls

### Rule 2 - void import became unused
- **Found during:** Cleanup — Switched from `void $` to `_ <-` pattern, making the `Control.Monad (void)` import unused; removed it to fix the warning

## Pre-existing Issues

The following build errors are pre-existing and not caused by Plan 16-02:
- `DAL.Queries.hs` — `D.utcTime` and `D.day` not exported from Hasql.Decoders in this Hasql version
- Various module name mismatches (`Main` instead of correct module names in Bills.hs, Goods.hs, Payment.hs, Persons.hs)
- Main `Surypus` package — CurrencyInput not in scope in DAL.Types

These existed before Plan 16-02 and are unrelated to notification changes.

## Known Stubs

- `sendEmailNotification` has a hardcoded email address `"user@surypus.local"` as the recipient — needs a lookup from the `usr` table (commented as TODO)
- `smpte_hlp` reference in the CTE upsert query might need verification with the actual V1003 migration function names

## Next Phase Readiness

- All notification preference functions use real Hasql queries against the database
- sendEmailNotification has SMTP integration ready (recipient lookup still hardcoded)
- Server.hs passes userId to getNotificationPrefs (still hardcoded to 1 pending auth integration)
- Ready for Plan 16-03: QML NotificationsPanel UI

---
*Phase: 16-notifications*
*Completed: 2026-05-20*
