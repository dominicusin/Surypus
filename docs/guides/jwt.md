# How JWT Authentication Works

## Overview

Surypus uses JSON Web Tokens (JWT) for stateless authentication and authorization.

## Core Concepts

- **Access Token** — short-lived token for API requests
- **Refresh Token** — long-lived token for obtaining new access tokens
- **Claims** — payload data embedded in the JWT (user ID, roles, permissions)
- **Secret** — symmetric key used to sign tokens

## Module Structure

```text
Surypus.JWT
├── Types        -- JWT types (Token, Claims, JwtHeader)
├── Generate     -- Token generation and signing
├── Validate     -- Token validation and claims verification
└── Refresh      -- Token refresh logic
```

## Token Flow

```text
Client                    API Server              Auth Service
  │                           │                         │
  │── login (credentials) ────▶│                         │
  │                           │── verify credentials ──▶│
  │                           │◀── access + refresh ────│
  │◀── access token + refresh ─│                         │
  │                           │                         │
  │── access token ───────────▶│                         │
  │                           │── validate JWT ─────────▶│
  │                           │◀── claims + permissions ─│
  │                           │                         │
  │◀── response ──────────────│                         │
```

## Claims Structure

```haskell
-- | JWT claims for Surypus authentication.
--
-- >>> jwtClaims (User "alice" [Role "Admin"]) "exp"
-- Claims {sub = "alice", roles = [Role "Admin"], ...}
data Claims = Claims
  { sub     :: UserId
  , roles   :: [Role]
  , permissions :: [Permission]
  , exp     :: Int
  }
```

## Security Properties

- Tokens are signed with HS256 (HMAC-SHA256)
- Access tokens expire after 15 minutes
- Refresh tokens expire after 7 days
- Token revocation is checked against the revocation list

## Related Modules

- `Surypus.RBAC` — RBAC and permissions
- `Surypus.Types` — core types

## See Also

- [RBAC Guide](../guides/rbac.md)
- [API: Auth endpoints](../API.md)
