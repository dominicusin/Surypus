---
inclusion: always
description: Technology stack and architecture
---
# Technology Stack

## Languages & Runtime
- **Haskell** (GHC 9.6.5, Stack LTS-22.21) — core backend and domain logic
- **Node.js** — GraphQL shim (`surypus-graphql/`), GSD tooling
- **C++/QML** (Qt 6.7+, CMake) — desktop frontend (`qml/`, `frontend/`)
- **SQL** (PostgreSQL 15+) — primary data store

## Frameworks & Libraries
- **Servant** + **Warp** — REST API server
- **Hasql** + **hasql-pool** — typed PostgreSQL queries (no ORM)
- **Aeson** — JSON serialization
- **Jose 0.10** + **cryptonite 0.30** — JWT auth (pinned; jose ≥0.11 uses crypton which breaks build)
- **WebSockets** + **wai-websockets** — real-time push
- **EKG** + **Prometheus** — metrics/observability
- **HSpec** + **QuickCheck** — testing
- **LiquidHaskell** — formal verification for financial calculations (in progress)
- **OPA (Rego)** — policy engine for RBAC (`opa/policies/`)

## Project Structure
```
Surypus.cabal          — main library (src/)
surypus-api/           — REST API server (Servant)
surypus-common/        — shared types
surypus-graphql/       — Node.js GraphQL shim
qml/                   — QML desktop app (Qt 6.7+)
web/                   — Web PWA (vanilla JS + Chart.js)
sql/migrations/        — Flyway-style numbered migrations (V001–V182+)
sql/core|event|aggregate|projection|policy/ — domain SQL
config/                — schema SQL files, Grafana, Prometheus
opa/policies/          — OPA RBAC policies
```

## Build & Tools
- **Stack**: `stack build`, `stack test`
- **CMake**: QML desktop build (`qml/CMakeLists.txt`)
- **Make**: `make` for common tasks (see `Makefile`)
- **Docker Compose**: local dev (`docker-compose.yml`, `docker/docker-compose.yml`)
- **Kubernetes**: prod manifests (`k8s/`)
- **Flyway-style migrations**: sequential SQL files, run via `config/init_db.sh`
- **HLint**: `.hlint.yaml` for Haskell linting

## Key Constraints
- jose pinned to `>=0.10 && <0.11` — do NOT upgrade without testing
- hashtables pinned to `1.4.2` for GHC 9.6.5 compatibility
- `allow-newer: true` in stack.yaml — be careful with dependency changes
