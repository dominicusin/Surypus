---
inclusion: always
description: Security requirements and practices
---
# Security Guidelines

## Authentication
- JWT (jose 0.10 + cryptonite 0.30) — access + refresh tokens
- Token generation in `surypus-api/src/Surypus/JWT/Token.hs`
- Auth middleware validates `Authorization: Bearer <token>` header
- Login endpoint: `POST /api/v1/login` → `LoginResponse { lrToken, lrRefreshToken, lrUserId, lrExpiresIn }`

## Authorization
- RBAC: `requirePermission` middleware checks permissions before handlers
- OPA policy engine: `opa/policies/rbac.rego`
- RBAC schema: `sql/core/V001__rbac_schema.sql`
- Roles/permissions defined in DB; checked at handler level

## Data Protection
- Sanitize all user input
- Use parameterized queries (Hasql — no string interpolation ever)
- Encrypt sensitive data at rest

## Secrets Management
- Never commit secrets to git
- Use environment variables
- Reference `.env.example` for required vars
- Never echo secret values in logs or responses
