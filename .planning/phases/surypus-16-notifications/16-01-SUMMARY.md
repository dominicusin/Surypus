---
phase: 16-notifications
plan: 01
subsystem: database, infra
tags: [postgres, smtp, mime-mail, hasql, notifications]
requires: []
provides:
  - notification table with indexes matching Notifications.hs queries
  - SMTP email module with env-var-based config
  - smtp-mail and mime-mail library dependencies
affects: [16-02-PLAN.md]

tech-stack:
  added: [smtp-mail-0.4.0.2, mime-mail-0.5.1]
  patterns: [SMTP email sending via sendMailWithLogin', MIME message construction via simpleMail']

key-files:
  created:
    - sql/migrations/V1003__notification_implementation.sql
    - surypus-api/src/Infrastructure/Email.hs
  modified:
    - surypus-api/surypus-api.cabal
    - stack.yaml

key-decisions:
  - "smtp-mail-0.4.0.2 used (latest available; 0.4.2.0 does not exist on Hackage)"
  - "Network.Mail.SMTP module (not Network.SMTP) from smtp-mail package"
  - "mime-mail 0.5.1 added with simpleMail' for plain-text email construction"
  - "EmailConfig loaded from env vars with sensible defaults for optional fields"
  - "V1003 adds usr_id BIGINT column to notification_prefs for Haskell Int64 compatibility (V182 had UUID user_id)"

requirements-completed: [NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04]

duration: 15min
completed: 2026-05-20
---

# Phase 16 - Plan 01: DB Migration + SMTP Infrastructure Summary

**SQL migration creating notification table with helper functions and idempotent SMTP email module backed by smtp-mail + mime-mail libraries**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-20T00:20:00Z
- **Completed:** 2026-05-20T00:35:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created `V1003__notification_implementation.sql` migration with:
  - `notification` table matching Notifications.hs column layout (id BIGSERIAL, ntype, priority, recipient_id, subject, body, status, created_at, read_at)
  - Indexes on recipient_id, status, and created_at DESC
  - Added `usr_id BIGINT` column to V182's `notification_prefs` table for Haskell Int64 compatibility
  - Helper functions: notification_create, notification_mark_read, notify_event, notification_get_digest
  - All statements idempotent (IF NOT EXISTS / CREATE OR REPLACE)
- Created `Infrastructure.Email` module with:
  - `EmailConfig` data type for SMTP server configuration
  - `loadEmailConfig` reading from SURYPUS_SMTP_* environment variables with sensible defaults
  - `sendEmail` wrapping `sendMailWithLogin'` from smtp-mail with try/catch for error handling
  - Uses `simpleMail'` from mime-mail for plain-text email construction
- Added `smtp-mail-0.4.0.2` and `mime-mail-0.5.1` to stack.yaml extra-deps
- Added `Infrastructure.Email` to surypus-api.cabal exposed-modules
- Build succeeds with no errors

## Task Commits

1. **Task 1: V1003 migration** - `611b450` (feat)
2. **Task 2: SMTP email module + cabal deps** - `f2d5f46` (feat)

## Files Created/Modified

- `sql/migrations/V1003__notification_implementation.sql` (created, 151 lines) - Idempotent migration with notification table, indexes, and PL/pgSQL helper functions
- `surypus-api/src/Infrastructure/Email.hs` (created, 75 lines) - SMTP email module with config, env-var loading, and send function
- `surypus-api/surypus-api.cabal` (modified) - Added Infrastructure.Email module and smtp-mail/mime-mail dependencies
- `stack.yaml` (modified) - Added smtp-mail-0.4.0.2 and mime-mail-0.5.1 to extra-deps

## Decisions Made

- Used `smtp-mail-0.4.0.2` (latest available; 0.4.2.0 doesn't exist on Hackage)
- Module is `Network.Mail.SMTP` from smtp-mail, not `Network.SMTP`
- Used `sendMailWithLogin'` for authenticated SMTP with explicit port (STARTTLS on 587)
- Used `simpleMail'` for plain-text-only email construction (simplest API from mime-mail 0.5.x)
- All SMTP credentials loaded from env vars; no hardcoded secrets
- V1003 extends V182's notification_prefs with usr_id BIGINT column for Haskell Int64 support

## Deviations from Plan

None - plan executed exactly as written (with minor version correction for smtp-mail).

## Issues Encountered

- `smtp-mail-0.4.2.0` not on Hackage; downgraded to `0.4.0.2` (latest available version)
- `Network.SMTP` module doesn't exist; actual module is `Network.Mail.SMTP`
- `mime-mail` 0.5.x uses `simpleMail'` (not `simpleMail`) and `plainPart` (not `plainTextPart`)
- Had to add `ScopedTypeVariables` extension for `try` exception type annotation

## User Setup Required

**External services require manual configuration.** Set these environment variables:
- `SURYPUS_SMTP_HOST` - SMTP server hostname (required)
- `SURYPUS_SMTP_PORT` - SMTP port (optional, default 587)
- `SURYPUS_SMTP_USERNAME` - SMTP auth username (optional)
- `SURYPUS_SMTP_PASSWORD` - SMTP auth password (optional)
- `SURYPUS_EMAIL_FROM` - Sender email (optional, default noreply@surypus.local)
- `SURYPUS_EMAIL_FROM_NAME` - Sender display name (optional, default "Surypus ERP")

## Next Phase Readiness

- `notification` table schema ready for Plan 16-02 full Notifications.hs rewrite
- `Infrastructure.Email` module ready for import by Plan 16-02's sendEmailNotification function
- Both smtp-mail and mime-mail resolved and compiled successfully

---
*Phase: 16-notifications*
*Completed: 2026-05-20*
