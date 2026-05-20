# Spec: JWT Auth Fix + Phase 16 Notifications

**Created:** 2026-05-19
**Status:** design

## Problem

Two critical gaps block production readiness:

1. **JWT auth is a stub** — `authMiddleware` accepts any bearer token without validation; `handleLogin` returns a fake string token. Any request with any `Authorization` header passes.
2. **Notifications are stubs** — `createNotification`, `sendEmailNotification`, `sendDigestNotification` all return `QueryError "Not implemented"`.

## Goals

1. Wire real HS256 JWT signing in `handleLogin` using the existing `JWT.generateToken` (jose 0.10).
2. Validate JWT on every protected request in `authMiddleware` using `JWT.verifyToken`.
3. Implement real DB-backed notification CRUD against the `notification` table.
4. Add email dispatch via SMTP (configurable via env vars, graceful no-op if unconfigured).
5. Add digest notification scheduling (daily/weekly summary).

## Out of Scope

- Refresh token rotation (deferred)
- Push notifications to Qt desktop (Phase 16 Wave 2)
- OPA RBAC integration (separate spec)

## Requirements

### JWT Auth
- REQ-JWT-1: `handleLogin` must return a cryptographically signed HS256 JWT containing `sub` (userId), `name` (username), `iat`, `exp` (1h).
- REQ-JWT-2: `authMiddleware` must reject requests with missing or invalid/expired JWT with HTTP 401.
- REQ-JWT-3: JWT secret loaded from `SURYPUS_JWT_SECRET` env var; fallback to dev default with a warning log.
- REQ-JWT-4: `/api/v1/login` is exempt from auth check.

### Notifications
- REQ-NOTIF-1: `POST /api/v1/notifications` creates a record in `notification` table (status=pending).
- REQ-NOTIF-2: `GET /api/v1/notifications` returns notifications for the authenticated user.
- REQ-NOTIF-3: `POST /api/v1/notifications/:id/read` marks notification as read (status=4).
- REQ-NOTIF-4: `GET /api/v1/notifications/prefs` and `PUT` update user notification preferences.
- REQ-NOTIF-5: `POST /api/v1/notifications/test` sends a test notification to the current user

... (truncated, run `kspec refresh` for AI-generated summary)