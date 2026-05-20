# Design: JWT Auth Fix + Phase 16 Notifications

**Spec:** `.kiro/specs/2026-05-19-jwt-auth-notifications/spec.md`
**Status:** ready for implementation

---

## Architecture Overview

Two independent concerns addressed in one spec:

```
┌─────────────────────────────────────────────────────┐
│  surypus-api                                        │
│                                                     │
│  POST /login ──► handleLogin                        │
│                    └─► DAL.Mutations.authenticateUser│
│                    └─► JWT.generateToken (HS256)    │
│                    └─► LoginResponse { token }      │
│                                                     │
│  ALL other routes ──► authMiddleware                │
│                         └─► JWT.verifyToken         │
│                         └─► 401 if invalid/missing  │
│                         └─► pass-through if valid   │
│                                                     │
│  /notifications/* ──► Notifications handlers        │
│                         └─► notification table (PG) │
│                         └─► SMTP (optional)         │
└─────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### JWT Auth (already implemented — verify only)

| File | Change |
|------|--------|
| `surypus-api/src/Surypus/JWT/Token.hs` | `generateToken` (HS256, jose 0.10) ✅ done |
| `surypus-api/src/Surypus/JWT/Token.hs` | `verifyToken` (decode + validate exp) ✅ done |
| `surypus-api/src/Surypus/API/Server.hs` | `handleLogin` calls `JWT.generateToken` ✅ done |
| `surypus-api/src/Surypus/API/Server.hs` | `authMiddleware` calls `JWT.verifyToken` ✅ done |

### Notifications (already implemented — verify only)

| File | Change |
|------|--------|
| `surypus-api/src/Surypus/API/Notifications.hs` | Real Hasql queries against `notification` table ✅ done |
| `surypus-api/src/Surypus/API/Server.hs` | 7 notification routes wired ✅ done |
| `config/schema_notifications.sql` | `notification` table schema ✅ exists |

---

## Data Models

### JWT Claims (jose ClaimsSet)
```
sub  : Text          -- userId as string
name : Text          -- username
iat  : NumericDate   -- issued at
exp  : NumericDate   -- now + 3600s
```

### Notification (DB table: `notification`)
```sql
id           BIGSERIAL PRIMARY KEY
ntype        SMALLINT NOT NULL REFERENCES notification_type(id)
priority     SMALLINT DEFAULT 3
recipient_id BIGINT NOT NULL REFERENCES person(id)
subject      VARCHAR(256) NOT NULL
body         TEXT
status       SMALLINT DEFAULT 0  -- 0=draft,1=pending,2=sent,3=delivered,4=read
created_at   TIMESTAMPTZ DEFAULT NOW()
```

### Notification API types (Haskell)
```haskell
data Notification = Notification
  { notifId    :: Text
  , notifTitle :: Text
  , notifBody  :: Maybe Text
  , notifStatus :: Text   -- "pending"|"sent"|"read"|...
  }

data NotificationInput = NotificationInput
  { niUserId :: Int64
  , niTitle  :: Text
  , niBody   :: Text
  , niType   :: Text
  }
```

---

## API Contracts

### Auth

```
POST /api/v1/login
  Body: { "lrUsername": "admin", "lrPassword": "..." }
  200:  { "lrToken": "<HS256 JWT>", "lrUserId": 1, "lrExpiresIn": 3600 }
  401:  "Invalid credentials"

ALL other endpoints:
  Header: Authorization: Bearer <token>
  401 if missing, expired, or invalid signature
```

### Notifications

```
GET  /api/v1/notifications
  200: [ { notifId, notifTitle, notifBody, notifStatus } ]

POST /api/v1/notifications
  Body: { niUserId, niTitle, niBody, niType }
  200: { notifId, notifTitle, notifBody, notifStatus: "pending" }

POST /api/v1/notifications/:id/read
  200: {}

GET  /api/v1/notifications/prefs
  200: { npEmail: bool, npPush: bool, npDigest: "daily"|"weekly"|"none" }

PUT  /api/v1/notifications/prefs
  Body: { npiEmail, npiPush, npiDigest }
  200: { npEmail, npPush, npDigest }

POST /api/v1/notifications/test
  200: {}

POST /api/v1/notifications/digest/:frequency
  200: {}
```

---

## Dependency Mapping

```
Server.hs
  ├── JWT.Token          (jose 0.10, cryptonite 0.30)
  ├── DAL.Mutations      (authenticateUser)
  └── Notifications.hs
        └── DAL.Database (usePool, Hasql)
              └── notification table (PostgreSQL)
```

**Environment variables:**
- `SURYPUS_JWT_SECRET` — HS256 signing key (fallback: `"dev-secret-change-in-production"`)
- `SURYPUS_SMTP_HOST` — if set, email dispatch attempted (not yet implemented; logged only)

---

## Technical Decisions

1. **HS256 over RS256** — simpler key management for single-service deployment; RS256 deferred until multi-service federation is needed.
2. **1h expiry, no refresh rotation** — refresh tokens deferred to avoid scope creep; acceptable for internal ERP.
3. **Notifications stored in DB, not queued** — avoids Redis/RabbitMQ dependency; acceptable for SMB load. Queue-based delivery deferred to Phase 20.
4. **SMTP is optional** — `SURYPUS_SMTP_HOST` absent → notification created in DB only, no email sent. Prevents startup failure in dev.
5. **`notification_type` id=1** hardcoded in `createNotification` — proper type lookup deferred; acceptable for Phase 16.

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| jose API changes between 0.10 and 0.11 | High | Pinned `>=0.10 && <0.11` in cabal |
| JWT secret in env var leaked via logs | Medium | Logger never prints env vars; secret only read in `getSigningKey` |
| `notification_type` id=1 may not exist in DB | Low | Seed migration inserts default types |
| `authMiddleware` path matching too broad | Low | Only `/api/v1/login` is exempt; all other paths validated |
| `verifyToken` error messages leak internals | Low | Only `Left _` branch checked; error string not forwarded to client |

---

## Implementation Status

All components are **already implemented** in this session:

- ✅ `JWT.Token.generateToken` — real HS256 signing
- ✅ `JWT.Token.verifyToken` — decode + validate
- ✅ `Server.hs authMiddleware` — validates token, exempts `/api/v1/login`
- ✅ `Server.hs handleLogin` — calls `JWT.generateToken`
- ✅ `Notifications.hs` — real Hasql queries (listNotifications, createNotification, markNotificationRead)
- ✅ `Server.hs` — 7 notification routes wired

**Next step:** `kspec verify` or `stack build` to confirm compilation.
